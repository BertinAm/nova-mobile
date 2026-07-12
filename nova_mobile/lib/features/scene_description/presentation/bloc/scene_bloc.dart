import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/connectivity_service.dart';
import '../../../../core/tts/tts_service.dart';
import '../../domain/usecases/describe_scene_usecase.dart';

abstract class SceneEvent extends Equatable {
  const SceneEvent();
  @override
  List<Object?> get props => [];
}

class RequestSceneDescription extends SceneEvent {
  const RequestSceneDescription();
}

abstract class SceneState extends Equatable {
  const SceneState();
  @override
  List<Object?> get props => [];
}

class SceneIdle extends SceneState {
  const SceneIdle();
}

class SceneLoading extends SceneState {
  const SceneLoading();
}

class SceneLoaded extends SceneState {
  final String description;
  const SceneLoaded(this.description);
  @override
  List<Object?> get props => [description];
}

class SceneOfflineError extends SceneState {
  const SceneOfflineError();
}

class SceneError extends SceneState {
  final String message;
  const SceneError(this.message);
  @override
  List<Object?> get props => [message];
}

class SceneBloc extends Bloc<SceneEvent, SceneState> {
  final DescribeSceneUseCase _describeScene;
  final ConnectivityService _connectivity;
  final TtsService _tts;
  final CameraService _camera;
  final AppDatabase _db;

  SceneBloc(
    this._describeScene,
    this._connectivity,
    this._tts,
    this._camera,
    this._db,
  ) : super(const SceneIdle()) {
    on<RequestSceneDescription>(_onRequest);
  }

  Future<void> _onRequest(
    RequestSceneDescription event,
    Emitter<SceneState> emit,
  ) async {
    final connected = await _connectivity.isConnected;
    if (!connected && !AppConstants.simulated) {
      emit(const SceneOfflineError());
      await _tts.speak(
        'You\'ll need an internet connection for this one. Please connect and try again.',
        priority: TtsPriority.high,
      );
      await _db.insertUsageEvent(moduleId: ModuleIds.scene, outcome: 'offline');
      return;
    }

    emit(const SceneLoading());
    await _tts.speak('Let me look at what\'s around you. One moment.', priority: TtsPriority.high);

    final image = await _camera.captureStill();
    final result = await _describeScene(image);
    await result.fold(
      (failure) async {
        emit(SceneError(failure.message));
        await _tts.speak(
          'I wasn\'t able to describe the scene this time. Please try again.',
          priority: TtsPriority.high,
        );
        await _db.insertUsageEvent(moduleId: ModuleIds.scene, outcome: 'error');
      },
      (description) async {
        emit(SceneLoaded(description));
        await _tts.speak(description, priority: TtsPriority.normal);
        await _db.insertUsageEvent(moduleId: ModuleIds.scene, outcome: 'described');
      },
    );
  }
}
