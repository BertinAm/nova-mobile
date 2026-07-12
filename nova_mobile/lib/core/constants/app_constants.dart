class AppConstants {
  AppConstants._();

  static const bool simulated = bool.fromEnvironment(
    'NOVA_SIMULATED',
    defaultValue: false,
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://nova-backend-r27n.onrender.com',
  );

  // Asset paths required by the mobile implementation guide.
  static const obstacleModelAsset = 'assets/models/obstacle_detection_v1.tflite';
  static const currencyModelAsset = 'assets/models/currency_detection_v1.tflite';
  static const faceDetectionModelAsset = 'assets/models/face_detection_blazeface.tflite';
  static const faceEmbeddingModelAsset = 'assets/models/face_embedding_mobilefacenet.tflite';
  static const cocoLabelsAsset = 'assets/labels/coco_labels.txt';
  static const cfaLabelsAsset = 'assets/labels/cfa_labels.txt';

  // MOD-01 thresholds from SRS and implementation guide.
  static const obstacleInputSize = 320;
  static const obstacleConfidenceThreshold = 0.55;
  static const nearThresholdMeters = 1.5;
  static const warningThresholdMeters = 3.0;
  static const obstacleAlertSuppressionSeconds = 2;
  static const obstacleTargetFrameIntervalMs = 100; // 10 FPS target.

  // MOD-04 thresholds.
  static const currencyInputSize = 224;
  static const currencyConfidenceThreshold = 0.85;

  // MOD-05 thresholds.
  static const faceDetectionInputSize = 128;
  static const faceEmbeddingInputSize = 112;
  static const faceMatchThreshold = 0.75;
  static const localFaceGalleryLimit = 20;

  // Backend paths.
  static const authRegisterPath     = '/auth/register';
  static const authLoginPath        = '/auth/login';
  static const authRefreshPath      = '/auth/refresh';
  static const sceneDescribePath    = '/scene/describe';
  static const facesEnrolPath       = '/faces/enrol';
  static const facesMatchPath       = '/faces/match';
  static const facesListPath        = '/faces/';
  static const modelsLatestPath     = '/models/latest';
  static const logsSyncPath         = '/logs/sync';
  static const feedbackSyncPath     = '/logs/feedback/sync';
  static const emergencyContactPath = '/emergency-contact/';
  static const healthPath           = '/health';
}

class ModuleIds {
  ModuleIds._();
  static const obstacle = 'MOD-01';
  static const ocr = 'MOD-02';
  static const scene = 'MOD-03';
  static const currency = 'MOD-04';
  static const face = 'MOD-05';
  static const faceEmbed = 'MOD-05-embed';
}
