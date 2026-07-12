import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/camera/camera_service.dart';
import 'core/constants/app_constants.dart';
import 'core/database/app_database.dart';
import 'core/data_collection/data_collection_service.dart';
import 'core/haptics/haptic_service.dart';
import 'core/model_update/model_update_service.dart';
import 'core/network/connectivity_service.dart';
import 'core/network/dio_client.dart';
import 'core/settings/settings_service.dart';
import 'core/sync/sync_service.dart';
import 'core/tts/tts_service.dart';
import 'core/location/location_service.dart';
import 'core/voice/voice_command_service.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/emergency_contact/data/datasources/emergency_contact_datasource.dart';
import 'features/emergency_contact/domain/repositories/emergency_contact_repository.dart';
import 'features/emergency_contact/presentation/bloc/emergency_contact_bloc.dart';
import 'features/home/presentation/bloc/home_bloc.dart';
import 'features/currency_detection/data/datasources/tflite_currency_datasource.dart';
import 'features/currency_detection/data/repositories/currency_repository_impl.dart';
import 'features/currency_detection/domain/repositories/currency_repository.dart';
import 'features/currency_detection/domain/usecases/classify_currency_usecase.dart';
import 'features/currency_detection/presentation/bloc/currency_bloc.dart';
import 'features/face_recognition/data/datasources/face_recognition_datasource.dart';
import 'features/face_recognition/data/repositories/face_repository_impl.dart';
import 'features/face_recognition/domain/repositories/face_repository.dart';
import 'features/face_recognition/domain/usecases/face_usecases.dart';
import 'features/face_recognition/presentation/bloc/face_bloc.dart';
import 'features/ocr/data/datasources/mlkit_ocr_datasource.dart';
import 'features/ocr/data/repositories/ocr_repository_impl.dart';
import 'features/ocr/domain/repositories/ocr_repository.dart';
import 'features/ocr/domain/usecases/recognize_text_usecase.dart';
import 'features/ocr/presentation/bloc/ocr_bloc.dart';
import 'features/obstacle_detection/data/datasources/tflite_obstacle_datasource.dart';
import 'features/obstacle_detection/data/repositories/obstacle_repository_impl.dart';
import 'features/obstacle_detection/domain/repositories/obstacle_repository.dart';
import 'features/obstacle_detection/domain/usecases/detect_obstacles_usecase.dart';
import 'features/obstacle_detection/presentation/bloc/obstacle_bloc.dart';
import 'features/scene_description/data/datasources/scene_remote_datasource.dart';
import 'features/scene_description/data/repositories/scene_repository_impl.dart';
import 'features/scene_description/domain/repositories/scene_repository.dart';
import 'features/scene_description/domain/usecases/describe_scene_usecase.dart';
import 'features/scene_description/presentation/bloc/scene_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // Core services.
  getIt.registerLazySingleton(() => const FlutterSecureStorage());
  getIt.registerLazySingleton(() => ConnectivityService());
  getIt.registerLazySingleton(() => DioClient(getIt()));
  getIt.registerLazySingleton(() => CameraService());
  getIt.registerLazySingleton(() => HapticService());

  final db = AppDatabase();
  await db.init();
  getIt.registerSingleton<AppDatabase>(db);

  // ─── Settings (must come before TTS so it can seed language/rate) ────────
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsService(prefs);
  getIt.registerSingleton<SettingsService>(settings);
  getIt.registerLazySingleton(() => LocationService());

  final tts = TtsService();
  await tts.init(settings.language.value);
  await tts.setSpeechRate(settings.speechRate.value);
  getIt.registerSingleton<TtsService>(tts);

  getIt.registerLazySingleton(() => VoiceCommandRouter());
  final voice = VoiceCommandService(getIt());
  await voice.init(settings.language.value.replaceAll('-', '_'));
  getIt.registerSingleton<VoiceCommandService>(voice);

  getIt.registerLazySingleton(() => SyncService(getIt(), getIt(), getIt()));
  getIt.registerLazySingleton(() => ModelUpdateService(getIt(), getIt(), getIt()));

  final dataCollection = DataCollectionService(getIt(), getIt());
  await dataCollection.init();
  getIt.registerSingleton<DataCollectionService>(dataCollection);

  getIt.registerFactory(() => HomeBloc(getIt(), getIt(), getIt(), getIt()));

  // Auth feature
  getIt.registerLazySingleton(() => AuthRemoteDatasource(getIt<DioClient>().client, getIt()));
  getIt.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(getIt()));
  getIt.registerFactory(() => AuthBloc(getIt(), getIt()));

  // Emergency Contact feature
  getIt.registerLazySingleton(() => EmergencyContactDatasource(getIt<DioClient>().client));
  getIt.registerLazySingleton<EmergencyContactRepository>(() => EmergencyContactRepositoryImpl(getIt()));
  getIt.registerFactory(() => EmergencyContactBloc(getIt()));

  // MOD-01 obstacle detection.
  final obstacleDs = TfliteObstacleDatasource();
  await obstacleDs.init();
  getIt.registerSingleton<TfliteObstacleDatasource>(obstacleDs);
  getIt.registerLazySingleton<ObstacleRepository>(() => ObstacleRepositoryImpl(getIt()));
  getIt.registerLazySingleton(() => DetectObstaclesUseCase(getIt()));
  getIt.registerFactory(() => ObstacleBloc(getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt()));

  // MOD-02 OCR.
  getIt.registerLazySingleton(() => MlKitOcrDatasource());
  getIt.registerLazySingleton<OcrRepository>(() => OcrRepositoryImpl(getIt()));
  getIt.registerLazySingleton(() => RecognizeTextUseCase(getIt()));
  getIt.registerFactory(() => OcrBloc(getIt(), getIt(), getIt(), getIt()));

  // MOD-03 scene description.
  getIt.registerLazySingleton(() => SceneRemoteDatasource(getIt<DioClient>().client));
  getIt.registerLazySingleton<SceneRepository>(() => SceneRepositoryImpl(getIt()));
  getIt.registerLazySingleton(() => DescribeSceneUseCase(getIt()));
  getIt.registerFactory(() => SceneBloc(getIt(), getIt(), getIt(), getIt(), getIt()));

  // MOD-04 currency detection.
  final currencyDs = TfliteCurrencyDatasource();
  await currencyDs.init();
  getIt.registerSingleton<TfliteCurrencyDatasource>(currencyDs);
  getIt.registerLazySingleton<CurrencyRepository>(() => CurrencyRepositoryImpl(getIt()));
  getIt.registerLazySingleton(() => ClassifyCurrencyUseCase(getIt()));
  getIt.registerFactory(() => CurrencyBloc(getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt()));

  // MOD-05 face recognition.
  getIt.registerLazySingleton(() => FaceRecognitionDatasource(getIt()));
  getIt.registerLazySingleton<FaceRepository>(() => FaceRepositoryImpl(getIt()));
  getIt.registerLazySingleton(() => GetContactsUseCase(getIt()));
  getIt.registerLazySingleton(() => EnrollFaceUseCase(getIt()));
  getIt.registerLazySingleton(() => RecogniseFaceUseCase(getIt()));
  getIt.registerLazySingleton(() => DeleteContactUseCase(getIt()));
  getIt.registerFactory(() => FaceBloc(getIt(), getIt(), getIt(), getIt(), getIt(), getIt(), getIt()));

  // Optional OTA check. It is skipped in simulation mode.
  if (!AppConstants.simulated) {
    await getIt<ModelUpdateService>().checkForUpdates(const [
      ModuleIds.obstacle,
      ModuleIds.currency,
      ModuleIds.faceEmbed,
    ]);
  }
}
