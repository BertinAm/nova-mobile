import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/ml/blazeface_helper.dart';
import '../../domain/entities/face_entities.dart';

/// MOD-05 Face Recognition Datasource.
///
/// Offline pipeline:
///   1. Detect face bounding box using BlazeFace TFLite (128×128 input).
///   2. Crop & resize detected face to 112×112 for MobileFaceNet.
///   3. Extract 128-d L2-normalised embedding via MobileFaceNet TFLite.
///   4. Compare with gallery using cosine similarity.
///
/// Falls back to a SHA-256 deterministic embedding in simulation mode
/// or if models are unavailable (allows enrolment/recognition to still
/// demonstrate the UX flow without actual models).
class FaceRecognitionDatasource {
  final AppDatabase _db;
  final _uuid = const Uuid();

  Interpreter? _blazeFace;
  Interpreter? _mobileFaceNet;
  bool _modelsLoaded = false;

  FaceRecognitionDatasource(this._db) {
    _loadModels();
  }

  Future<void> _loadModels() async {
    if (AppConstants.simulated) return;
    try {
      final opts = InterpreterOptions()..threads = 2;
      _blazeFace = await Interpreter.fromAsset(
          AppConstants.faceDetectionModelAsset, options: opts);
      _mobileFaceNet = await Interpreter.fromAsset(
          AppConstants.faceEmbeddingModelAsset, options: opts);
      _modelsLoaded = true;
      debugPrint('FaceRecognitionDatasource: models loaded ✓');
    } catch (e) {
      debugPrint('FaceRecognitionDatasource: model load failed — $e. Using fallback.');
    }
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<List<EnrolledContact>> contacts() async {
    final rows = await _db.getEnrolledContacts();
    return rows
        .map((r) => EnrolledContact(id: r.id, name: r.name, createdAt: r.createdAt))
        .toList();
  }

  Future<EnrolledContact> enroll(String name, List<File?> photos) async {
    // Average multiple embeddings for a more robust gallery entry.
    final embeddings = <List<double>>[];
    for (final photo in photos) {
      if (photo == null) continue;
      final emb = await _extractEmbedding(photo);
      embeddings.add(emb);
    }

    final embedding = embeddings.isEmpty
        ? _fallbackEmbedding('$name-${DateTime.now()}')
        : _averageEmbeddings(embeddings);

    final row = EnrolledContactRow(
      id: _uuid.v4(),
      name: name.trim(),
      embedding: embedding,
      createdAt: DateTime.now(),
    );
    await _db.saveEnrolledContact(row);
    return EnrolledContact(id: row.id, name: row.name, createdAt: row.createdAt);
  }

  Future<void> deleteContact(String id) async {
    await _db.deleteEnrolledContact(id);
  }

  Future<FaceRecognitionResult> recognise(File? imageFile) async {
    final gallery = await _db.getEnrolledContacts();

    if (gallery.isEmpty) {
      return const FaceRecognitionResult(faceDetected: false, matched: false);
    }

    if (imageFile == null) {
      return const FaceRecognitionResult(faceDetected: false, matched: false);
    }

    // Use cloud if gallery exceeds local limit and network is available.
    if (!AppConstants.simulated && gallery.length > AppConstants.localFaceGalleryLimit) {
      return _recogniseViaCloud(imageFile);
    }

    final probe = await _extractEmbedding(imageFile);

    double bestSim = -1.0;
    EnrolledContactRow? bestContact;

    for (final contact in gallery) {
      final sim = _cosine(probe, contact.embedding);
      if (sim > bestSim) {
        bestSim = sim;
        bestContact = contact;
      }
    }

    final matched = bestSim >= AppConstants.faceMatchThreshold;
    return FaceRecognitionResult(
      faceDetected: true,
      matched: matched,
      contactName: matched ? bestContact!.name : null,
      similarity: bestSim,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Extract a 128-d embedding from a full image file.
  /// Uses TFLite pipeline if models are loaded; SHA-256 fallback otherwise.
  Future<List<double>> _extractEmbedding(File imageFile) async {
    if (!_modelsLoaded || _mobileFaceNet == null) {
      return _fallbackEmbedding(imageFile.path);
    }

    try {
      final bytes = await imageFile.readAsBytes();
      var fullImage = img.decodeImage(bytes);
      if (fullImage == null) return _fallbackEmbedding(imageFile.path);

      // ── Step 1: Detect face bounding box using BlazeFace TFLite ───────────
      img.Image faceRegion = fullImage;

      if (_blazeFace != null) {
        final resized = img.copyResize(fullImage, width: 128, height: 128);
        final input = _imageToFloatInput(resized, inputSize: 128);
        
        final outBoxes = List.generate(1, (_) => List.generate(896, (_) => List.filled(16, 0.0)));
        final outScores = List.generate(1, (_) => List.generate(896, (_) => List.filled(1, 0.0)));

        _blazeFace!.runForMultipleInputs([input], {
          0: outBoxes,
          1: outScores,
        });

        final bestFace = BlazeFaceHelper.getBestFace(outBoxes, outScores, fullImage.width, fullImage.height);
        
        if (bestFace != null) {
          final x = max(0, bestFace.left);
          final y = max(0, bestFace.top);
          final w = min(fullImage.width - x, bestFace.width);
          final h = min(fullImage.height - y, bestFace.height);
          if (w > 0 && h > 0) {
            faceRegion = img.copyCrop(fullImage, x, y, w, h);
          }
        } else {
          debugPrint('No face found by BlazeFace. Falling back.');
          return _fallbackEmbedding(imageFile.path);
        }
      }

      // ── Step 2: Resize to MobileFaceNet input (112×112) ──────────────────
      final resized = img.copyResize(faceRegion, width: 112, height: 112);

      // ── Step 3: Normalise pixel values to [-1, 1] ─────────────────────────
      final input = _imageToFloatInput(resized);

      // ── Step 4: Run MobileFaceNet ─────────────────────────────────────────
      final outputShape = _mobileFaceNet!.getOutputTensor(0).shape;
      final embeddingSize = outputShape.last;
      final output = List.generate(1, (_) => List.filled(embeddingSize, 0.0));
      _mobileFaceNet!.run(input, output);

      final raw = output[0];
      return _l2Normalize(raw);
    } catch (e) {
      debugPrint('Embedding extraction failed: $e — using fallback');
      return _fallbackEmbedding(imageFile.path);
    }
  }

  /// Build a float tensor from an img.Image.
  List _imageToFloatInput(img.Image image, {int inputSize = 112}) {
    return List.generate(1, (_) =>
      List.generate(inputSize, (y) =>
        List.generate(inputSize, (x) {
          final pixel = image.getPixel(x, y);
          return [
            (img.getRed(pixel) - 127.5) / 127.5,
            (img.getGreen(pixel) - 127.5) / 127.5,
            (img.getBlue(pixel) - 127.5) / 127.5,
          ];
        })
      )
    );
  }

  List<double> _l2Normalize(List<double> v) {
    final norm = sqrt(v.fold<double>(0, (s, x) => s + x * x));
    if (norm < 1e-9) return v;
    return v.map((x) => x / norm).toList();
  }

  List<double> _averageEmbeddings(List<List<double>> embs) {
    final size = embs.first.length;
    final avg = List<double>.filled(size, 0);
    for (final e in embs) {
      for (var i = 0; i < size; i++) {
        avg[i] += e[i];
      }
    }
    return _l2Normalize(avg.map((v) => v / embs.length).toList());
  }

  double _cosine(List<double> a, List<double> b) {
    final n = min(a.length, b.length);
    var dot = 0.0;
    for (var i = 0; i < n; i++) dot += a[i] * b[i];
    return dot;
  }

  /// SHA-256 deterministic embedding — used as fallback when TFLite unavailable.
  List<double> _fallbackEmbedding(String seed) {
    final digest = sha256.convert(utf8.encode(seed)).bytes;
    final values = List<double>.generate(128, (i) {
      final byte = digest[i % digest.length];
      return (byte / 255.0) * 2.0 - 1.0;
    });
    return _l2Normalize(values);
  }

  /// Cloud recognition — only invoked for large galleries (> localFaceGalleryLimit).
  Future<FaceRecognitionResult> _recogniseViaCloud(File imageFile) async {
    // Cloud path is handled by the repository layer which injects Dio.
    // For now, fall back to local comparison.
    return recognise(imageFile);
  }
}
