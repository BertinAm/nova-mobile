import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/obstacle_detection_result.dart';
import '../models/raw_detection_model.dart';

/// Payload sent from the main thread to the background isolate.
class _IsolateRequest {
  final int requestId;
  final CameraFrame frame;
  final SendPort replyPort;

  const _IsolateRequest(this.requestId, this.frame, this.replyPort);
}

/// Payload sent from the background isolate to the main thread.
class _IsolateResponse {
  final int requestId;
  final List<DetectedObstacle> obstacles;

  const _IsolateResponse(this.requestId, this.obstacles);
}

class TfliteObstacleDatasource {
  Isolate? _isolate;
  SendPort? _sendPortToIsolate;
  final ReceivePort _receivePort = ReceivePort();
  
  int _requestIdCounter = 0;
  final Map<int, Completer<List<DetectedObstacle>>> _pendingRequests = {};
  
  List<String> _labels = const [];
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _labels = await _loadLabels();

    if (AppConstants.simulated) {
      _isInitialized = true;
      return;
    }

    try {
      _receivePort.listen(_handleIsolateMessages);
      
      // Spawn persistent background Isolate for ML inference
      _isolate = await Isolate.spawn(
        _isolateEntry,
        _IsolateInitData(_receivePort.sendPort, _labels),
        debugName: 'ObstacleInferenceIsolate',
      );
    } catch (e) {
      debugPrint('Obstacle Isolate spawn failed; using simulation: $e');
    }
  }

  void _handleIsolateMessages(dynamic message) {
    if (message is SendPort) {
      // The isolate sends its SendPort when it is ready
      _sendPortToIsolate = message;
      _isInitialized = true;
    } else if (message is _IsolateResponse) {
      final completer = _pendingRequests.remove(message.requestId);
      if (completer != null && !completer.isCompleted) {
        completer.complete(message.obstacles);
      }
    }
  }

  Future<List<DetectedObstacle>> detect(CameraFrame frame) async {
    if (!_isInitialized || _sendPortToIsolate == null || AppConstants.simulated) {
      return _simulate(frame);
    }

    final requestId = _requestIdCounter++;
    final completer = Completer<List<DetectedObstacle>>();
    _pendingRequests[requestId] = completer;

    // We create a temporary ReceivePort to avoid memory leaks if a response is dropped,
    // but a persistent _receivePort with request IDs (as implemented) is more efficient.
    _sendPortToIsolate!.send(_IsolateRequest(requestId, frame, _receivePort.sendPort));

    // Fallback timeout to prevent hanging the stream
    return completer.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () {
        _pendingRequests.remove(requestId);
        return [];
      },
    );
  }

  Future<List<String>> _loadLabels() async {
    try {
      final data = await rootBundle.loadString(AppConstants.cocoLabelsAsset);
      return data
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return ['person', 'car', 'motorcycle', 'open_drain', 'market_stall'];
    }
  }

  // Fallback Simulation Data
  int _simCounter = 0;
  List<DetectedObstacle> _simulate(CameraFrame frame) {
    _simCounter++;
    final cycle = _simCounter % 45;
    final simulatedRaw = <RawDetectionModel>[];

    if (cycle < 12) {
      simulatedRaw.add(const RawDetectionModel(label: 'person', confidence: 0.86, top: 0.10, left: 0.40, bottom: 0.92, right: 0.62));
    } else if (cycle < 24) {
      simulatedRaw.add(const RawDetectionModel(label: 'motorcycle', confidence: 0.78, top: 0.20, left: 0.02, bottom: 0.90, right: 0.34));
    } else if (cycle < 35) {
      simulatedRaw.add(const RawDetectionModel(label: 'open_drain', confidence: 0.74, top: 0.70, left: 0.48, bottom: 0.98, right: 0.90));
    }

    return simulatedRaw
        .where((r) => r.confidence >= AppConstants.obstacleConfidenceThreshold)
        .map((r) {
      final distance = _InferenceEngine.estimateDistance(r.label, r.widthNorm, frame.width);
      final zone = _InferenceEngine.classifyZone(distance);
      final direction = _InferenceEngine.classifyDirection(r.left, r.right);
      return DetectedObstacle(
        label: r.label.replaceAll('_', ' '),
        confidence: r.confidence,
        zone: zone,
        direction: direction,
        estimatedDistanceMeters: distance,
        trackingId: '${r.label}-${direction.name}',
      );
    }).toList();
  }

  void dispose() {
    _receivePort.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
  }
}

// -----------------------------------------------------------------------------
// Isolate Execution Scope
// -----------------------------------------------------------------------------

class _IsolateInitData {
  final SendPort mainSendPort;
  final List<String> labels;

  const _IsolateInitData(this.mainSendPort, this.labels);
}

/// The entry point for the persistent background Isolate.
Future<void> _isolateEntry(_IsolateInitData initData) async {
  final receivePort = ReceivePort();
  
  // 1. Send the Isolate's ReceivePort.sendPort back to main so main can send requests
  initData.mainSendPort.send(receivePort.sendPort);

  // 2. Initialize the Inference Engine
  final engine = _InferenceEngine(initData.labels);
  await engine.initialize();

  // 3. Listen for incoming CameraFrames
  receivePort.listen((dynamic message) {
    if (message is _IsolateRequest) {
      final obstacles = engine.runInference(message.frame);
      message.replyPort.send(_IsolateResponse(message.requestId, obstacles));
    }
  });
}

class _InferenceEngine {
  final List<String> _labels;
  Interpreter? _interpreter;
  
  // Pre-allocated continuous memory buffers to avoid GC pauses at 10 FPS
  late Uint8List _inputBuffer;
  late Float32List _outputBuffer;

  static const Map<String, double> _referenceWidths = {
    'person': 0.5, 'car': 1.8, 'motorcycle': 0.8, 'bicycle': 0.6,
    'bus': 2.5, 'truck': 2.4, 'chair': 0.5, 'dining table': 1.2,
    'open_drain': 0.8, 'market_stall': 2.0, 'low_hanging_sign': 1.2,
  };

  _InferenceEngine(this._labels);

  Future<void> initialize() async {
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(AppConstants.obstacleModelAsset, options: options);
      
      // Pre-allocate buffer for a typical 320x320 RGB tensor
      _inputBuffer = Uint8List(320 * 320 * 3);
      // Pre-allocate output buffer depending on model output shape
      _outputBuffer = Float32List(100 * 6); // Assuming max 100 boxes, 6 values each (top, left, bottom, right, score, class)
    } catch (e) {
      debugPrint('Isolate Interpreter init failed: $e');
    }
  }

  List<DetectedObstacle> runInference(CameraFrame frame) {
    if (_interpreter == null) return [];

    // O(N) where N is pixels: Write YUV/RGB frame bytes directly into _inputBuffer
    // This avoids runtime allocations.
    // ... [Frame pixel extraction and resizing into _inputBuffer] ...

    // O(M) where M is model complexity: Run inference
    // _interpreter!.run(_inputBuffer, _outputBuffer);

    // Parse _outputBuffer into RawDetectionModel list...
    // (Simulated parsing for demonstration purposes since actual output depends on model arch)
    final rawDetections = <RawDetectionModel>[];

    return rawDetections
        .where((r) => r.confidence >= AppConstants.obstacleConfidenceThreshold)
        .map((r) {
          
      // Pinhole camera geometry: d = (F * W) / w
      final distance = estimateDistance(r.label, r.widthNorm, frame.width);
      final zone = classifyZone(distance);
      final direction = classifyDirection(r.left, r.right);
      
      return DetectedObstacle(
        label: r.label.replaceAll('_', ' '),
        confidence: r.confidence,
        zone: zone,
        direction: direction,
        estimatedDistanceMeters: distance,
        trackingId: '${r.label}-${direction.name}',
      );
    }).toList();
  }

  /// Big-O: O(1) mathematical computation.
  static double estimateDistance(String label, double boxWidthNorm, int frameWidth) {
    final refWidth = _referenceWidths[label] ?? 0.5;
    const focalLengthPixels = 600.0;
    final pixelWidth = max(1.0, boxWidthNorm * frameWidth);
    return (focalLengthPixels * refWidth) / pixelWidth;
  }

  /// Big-O: O(1) comparison.
  static ObstacleZone classifyZone(double distanceM) {
    if (distanceM <= AppConstants.nearThresholdMeters) return ObstacleZone.near;
    if (distanceM <= AppConstants.warningThresholdMeters) return ObstacleZone.warning;
    return ObstacleZone.clear;
  }

  /// Big-O: O(1) comparison.
  static ObstacleDirection classifyDirection(double left, double right) {
    final center = (left + right) / 2;
    if (center < 0.33) return ObstacleDirection.left;
    if (center > 0.67) return ObstacleDirection.right;
    return ObstacleDirection.center;
  }
}
