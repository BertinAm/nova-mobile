import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/haptics/haptic_service.dart';
import '../../../../core/tts/tts_service.dart';
import '../../../../core/voice/voice_command_service.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final VoiceCommandService _voiceService;
  final VoiceCommandRouter _voiceRouter;
  final TtsService _ttsService;
  final HapticService _hapticService;

  StreamSubscription? _voiceRouterSub;
  Timer? _autoStopTimer;

  static const _menuLabels = [
    'Obstacle Detection',
    'Read Text',
    'Describe Scene',
    'Identify Money',
    'Recognize Faces',
    'Settings'
  ];

  static const _routes = [
    '/obstacle',
    '/ocr',
    '/scene',
    '/currency',
    '/faces',
    '/settings'
  ];

  HomeBloc(
    this._voiceService,
    this._voiceRouter,
    this._ttsService,
    this._hapticService,
  ) : super(const HomeState()) {
    on<HomeVoiceStartRequested>(_onVoiceStart);
    on<HomeVoiceStopRequested>(_onVoiceStop);
    on<HomeVoiceAutoStopTriggered>(_onVoiceAutoStop);
    on<HomeSpatialExploreUpdated>(_onSpatialExploreUpdated);
    on<HomeSpatialExploreEnded>(_onSpatialExploreEnded);
    on<HomeVoiceCommandReceived>(_onVoiceCommandReceived);

    _voiceRouterSub = _voiceRouter.commands.listen((command) {
      add(HomeVoiceCommandReceived(command));
    });
  }

  Future<void> _onVoiceStart(
    HomeVoiceStartRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isListening: true, clearNavigation: true));
    await _hapticService.vibrate();
    await _ttsService.speak(
      'Listening.',
      priority: TtsPriority.high,
      interrupt: true,
    );
    _voiceService.startListening();

    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(const Duration(seconds: 30), () {
      if (!isClosed) add(const HomeVoiceAutoStopTriggered());
    });
  }

  void _onVoiceStop(
    HomeVoiceStopRequested event,
    Emitter<HomeState> emit,
  ) {
    _autoStopTimer?.cancel();
    _voiceService.stopListening();
    emit(state.copyWith(isListening: false, clearNavigation: true));
  }

  void _onVoiceAutoStop(
    HomeVoiceAutoStopTriggered event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(isListening: false, clearNavigation: true));
  }

  Future<void> _onSpatialExploreUpdated(
    HomeSpatialExploreUpdated event,
    Emitter<HomeState> emit,
  ) async {
    if (event.index == state.hoveredIndex) return;
    
    if (event.index >= 0 && event.index < _menuLabels.length) {
      emit(state.copyWith(hoveredIndex: event.index, clearNavigation: true));
      await _hapticService.selectionClick();
      await _ttsService.speak(
        'Option ${event.index + 1}. ${_menuLabels[event.index]}',
        priority: TtsPriority.high,
        interrupt: true,
      );
    } else if (state.hoveredIndex != -1) {
      emit(state.copyWith(hoveredIndex: -1, clearNavigation: true));
    }
  }

  Future<void> _onSpatialExploreEnded(
    HomeSpatialExploreEnded event,
    Emitter<HomeState> emit,
  ) async {
    if (event.index >= 0 && event.index < _routes.length) {
      await _hapticService.lightImpact();
      await _ttsService.speak(
        'Opening ${_menuLabels[event.index]}.',
        priority: TtsPriority.high,
        interrupt: true,
      );
      emit(state.copyWith(hoveredIndex: -1, navigationTarget: _routes[event.index]));
      // Immediately clear navigation target after emit so it doesn't fire twice
      emit(state.copyWith(clearNavigation: true));
    }
  }

  Future<void> _onVoiceCommandReceived(
    HomeVoiceCommandReceived event,
    Emitter<HomeState> emit,
  ) async {
    int? targetIndex;
    switch (event.command) {
      case VoiceCommand.option1: targetIndex = 0; break;
      case VoiceCommand.option2: targetIndex = 1; break;
      case VoiceCommand.option3: targetIndex = 2; break;
      case VoiceCommand.option4: targetIndex = 3; break;
      case VoiceCommand.option5: targetIndex = 4; break;
      case VoiceCommand.option6: targetIndex = 5; break;
      default: return; // ignore other global commands here
    }

    _autoStopTimer?.cancel();
    emit(state.copyWith(isListening: false, hoveredIndex: -1, navigationTarget: _routes[targetIndex]));
    emit(state.copyWith(clearNavigation: true));
  }

  @override
  Future<void> close() {
    _autoStopTimer?.cancel();
    _voiceRouterSub?.cancel();
    return super.close();
  }
}
