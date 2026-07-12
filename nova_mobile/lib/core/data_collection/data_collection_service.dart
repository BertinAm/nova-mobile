import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../constants/app_constants.dart';
import '../ml/blazeface_helper.dart';
import '../network/dio_client.dart';
import '../settings/settings_service.dart';

/// Service responsible for capturing low-confidence / error frames
/// and uploading them to the backend for training data collection.
///
/// Privacy guarantee: any face detected by the on-device BlazeFace model is
/// blurred at the exact bounding-box level before the image ever leaves the
/// device.  If detection fails for any reason the whole image is blurred
/// as a safe fallback.
class DataCollectionService {
  final DioClient _dioClient;
  final SettingsService _settings;

  Interpreter? _blazeFace;

  DataCollectionService(this._dioClient, this._settings);

  Future<void> init() async {
    try {
      if (!AppConstants.simulated) {
        final opts = InterpreterOptions()..threads = 1;
        _blazeFace = await Interpreter.fromAsset(
          AppConstants.faceDetectionModelAsset,
          options: opts,
        );
        debugPrint('DataCollectionService: BlazeFace loaded ✓');
      } else {
        debugPrint('DataCollectionService: simulated mode — BlazeFace skipped.');
      }
    } catch (e) {
      debugPrint('DataCollectionService: failed to load BlazeFace — $e. Will blur entire frame.');
    }
  }

  /// Upload a "hard case" frame to the backend for model retraining.
  /// Does nothing if the user has not given consent.
  /// Handles 403 (consent not registered on server) gracefully without retry-looping.
  Future<void> uploadHardCase({
    required File imageFile,
    required String moduleId,
    required String outcome,
    double? confidenceScore,
  }) async {
    if (!_settings.dataCollectionConsent.value) return;

    try {
      final processedBytes = await _blurFacesAndCompress(imageFile);
      if (processedBytes == null) {
        debugPrint('DataCollectionService: upload aborted — face blurring failed.');
        return;
      }

      final formData = FormData.fromMap({
        'module_id': moduleId,
        'outcome': outcome,
        if (confidenceScore != null) 'confidence_score': confidenceScore,
        'file': MultipartFile.fromBytes(processedBytes, filename: 'hardcase.jpg'),
      });

      final resp = await _dioClient.client.post(
        '/training-data/upload',
        data: formData,
      );

      if (resp.statusCode == 201) {
        debugPrint('DataCollectionService: hard case uploaded — ${resp.data}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) {
        // Server says consent not registered — toggle is probably out of sync.
        // Do NOT retry; just log and bail.
        debugPrint('DataCollectionService: 403 — server consent not set. Skipping upload.');
      } else if (e.response?.statusCode == 413) {
        debugPrint('DataCollectionService: 413 — image too large even after compression.');
      } else {
        debugPrint('DataCollectionService: upload failed — ${e.message}');
      }
    } catch (e) {
      debugPrint('DataCollectionService: unexpected error — $e');
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Run BlazeFace on the image, blur every detected face at the bounding-box
  /// level, then compress to JPEG ≤ 5 MB.
  Future<List<int>?> _blurFacesAndCompress(File file) async {
    try {
      final imageBytes = await file.readAsBytes();
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return null;

      img.Image processed = decoded;

      if (_blazeFace != null) {
        try {
          const inputSize = 128;
          final resized = img.copyResize(processed, width: inputSize, height: inputSize);
          final input = _imageToFloatInput(resized, inputSize);

          final outBoxes = List.generate(1, (_) => List.generate(896, (_) => List.filled(16, 0.0)));
          final outScores = List.generate(1, (_) => List.generate(896, (_) => List.filled(1, 0.0)));

          _blazeFace!.runForMultipleInputs([input], {0: outBoxes, 1: outScores});

          final faces = BlazeFaceHelper.getAllFaces(
            outBoxes, outScores, processed.width, processed.height,
          );

          if (faces.isNotEmpty) {
            debugPrint('DataCollectionService: blurring ${faces.length} face(s).');
            for (final rect in faces) {
              final x = max(0, rect.left);
              final y = max(0, rect.top);
              final w = min(processed.width - x, rect.width);
              final h = min(processed.height - y, rect.height);
              if (w > 0 && h > 0) {
                final crop = img.copyCrop(processed, x, y, w, h);
                final blurred = img.gaussianBlur(crop, 25);
                for (int cy = 0; cy < h; cy++) {
                  for (int cx = 0; cx < w; cx++) {
                    processed.setPixel(x + cx, y + cy, blurred.getPixel(cx, cy));
                  }
                }
              }
            }
          } else {
            debugPrint('DataCollectionService: no faces detected — uploading as-is.');
          }
        } catch (inferErr) {
          // Inference error → safest fallback: blur the whole image.
          debugPrint('DataCollectionService: BlazeFace inference error — $inferErr. Blurring entire image.');
          processed = img.gaussianBlur(processed, 25);
        }
      } else {
        // Model unavailable → always blur everything.
        debugPrint('DataCollectionService: no model — blurring entire image.');
        processed = img.gaussianBlur(processed, 25);
      }

      // Compress to JPEG, targeting < 5 MB.
      var quality = 85;
      var encoded = img.encodeJpg(processed, quality: quality);
      while (encoded.length > 5 * 1024 * 1024 && quality > 30) {
        quality -= 10;
        encoded = img.encodeJpg(processed, quality: quality);
      }
      return encoded;
    } catch (e) {
      debugPrint('DataCollectionService: _blurFacesAndCompress failed — $e');
      return null;
    }
  }

  /// Build a [1, size, size, 3] float tensor normalised to [-1, 1].
  List _imageToFloatInput(img.Image image, int size) {
    return List.generate(1, (_) =>
      List.generate(size, (y) =>
        List.generate(size, (x) {
          final pixel = image.getPixel(x, y);
          return [
            (img.getRed(pixel) - 127.5) / 127.5,
            (img.getGreen(pixel) - 127.5) / 127.5,
            (img.getBlue(pixel) - 127.5) / 127.5,
          ];
        }),
      ),
    );
  }
}
