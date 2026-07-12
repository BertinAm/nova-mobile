import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/tts/tts_service.dart';
import '../../domain/entities/obstacle_detection_result.dart';
import '../../domain/services/alert_suppression_policy.dart';
import '../../domain/usecases/detect_obstacles_usecase.dart';

abstract class ObstacleEvent extends Equatable {
  const ObstacleEvent();
  @override
  List<Object?> get props => [];
}

class StartObstacleDetection extends ObstacleEvent {
  const StartObstacleDetection();
}

class StopObstacleDetection extends ObstacleEvent {
  const StopObstacleDetection();
}

class _ObstaclesDetected extends ObstacleEvent {
  final List<DetectedObstacle> obstacles;
  const _ObstaclesDetected(this.obstacles);
  @override
  List<Object?> get props => [obstacles];
}

class _ObstacleFailure extends ObstacleEvent {
  final Failure failure;
  const _ObstacleFailure(this.failure);
  @override
  List<Object?> get props => [failure];
}

abstract class ObstacleState extends Equatable {
  const ObstacleState();
  @override
  List<Object?> get props => [];
}

class ObstacleIdle extends ObstacleState {
  const ObstacleIdle();
}

class ObstacleDetecting extends ObstacleState {
  final List<DetectedObstacle> obstacles;
  const ObstacleDetecting(this.obstacles);
  @override
  List<Object?> get props => [obstacles];
}

class ObstacleError extends ObstacleState {
  final String message;
  const ObstacleError(this.message);
  @override
  List<Object?> get props => [message];
}

class ObstacleBloc extends Bloc<ObstacleEvent, ObstacleState> {
  final CameraService _camera;
  final DetectObstaclesUseCase _detectUseCase;
  final TtsService _tts;
  final HapticService _haptics;
  final AppDatabase _db;

  final AlertSuppressionPolicy _suppression = AlertSuppressionPolicy(
    suppressionPeriod: const Duration(
      seconds: AppConstants.obstacleAlertSuppressionSeconds,
    ),
  );

  StreamSubscription? _detectionSubscription;

  ObstacleBloc(
    this._camera,
    this._detectUseCase,
    this._tts,
    this._haptics,
    this._db,
  ) : super(const ObstacleIdle()) {
    on<StartObstacleDetection>(_onStart);
    on<StopObstacleDetection>(_onStop);
    on<_ObstaclesDetected>(_onObstaclesDetected);
    on<_ObstacleFailure>(_onFailure);
  }

  Future<void> _onStart(
    StartObstacleDetection event,
    Emitter<ObstacleState> emit,
  ) async {
    await _detectionSubscription?.cancel();
    await _camera.initialize();
    await _tts.speak('Scanning for obstacles. Walk carefully.', priority: TtsPriority.high);

    _detectionSubscription = _detectUseCase(_camera.frames()).listen(
      (result) => result.fold(
        (failure) => add(_ObstacleFailure(failure)),
        (obstacles) => add(_ObstaclesDetected(obstacles)),
      ),
    );

    await _db.insertUsageEvent(moduleId: ModuleIds.obstacle, outcome: 'started');
    emit(const ObstacleDetecting([]));
  }

  Future<void> _onObstaclesDetected(
    _ObstaclesDetected event,
    Emitter<ObstacleState> emit,
  ) async {
    final now = DateTime.now();

    for (final obstacle in event.obstacles) {
      if (!_suppression.shouldAlert(obstacle, now)) continue;

      final urgent = obstacle.zone == ObstacleZone.near;
      if (urgent) {
        await _haptics.critical();
      } else {
        await _haptics.warning();
      }

      await _tts.speak(
        obstacle.alertText,
        priority: urgent ? TtsPriority.critical : TtsPriority.high,
        interrupt: urgent,
      );

      await _db.insertUsageEvent(
        moduleId: ModuleIds.obstacle,
        outcome: '${obstacle.label}:${obstacle.zoneName}',
        confidenceScore: obstacle.confidence,
      );
    }

    emit(ObstacleDetecting(event.obstacles));
  }

  Future<void> _onFailure(
    _ObstacleFailure event,
    Emitter<ObstacleState> emit,
  ) async {
    await _tts.speak(
      'Something went wrong with obstacle detection. Try going back and starting again.',
      priority: TtsPriority.high,
    );
    emit(ObstacleError(event.failure.message));
  }

  Future<void> _onStop(
    StopObstacleDetection event,
    Emitter<ObstacleState> emit,
  ) async {
    await _detectionSubscription?.cancel();
    _suppression.clear();
    await _db.insertUsageEvent(moduleId: ModuleIds.obstacle, outcome: 'stopped');
    await _tts.speak('Scanning paused.', priority: TtsPriority.normal);
    emit(const ObstacleIdle());
  }

  @override
  Future<void> close() async {
    await _detectionSubscription?.cancel();
    return super.close();
  }
}
