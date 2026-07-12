import 'package:equatable/equatable.dart';

import '../../../../core/voice/voice_command_service.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class HomeVoiceStartRequested extends HomeEvent {
  const HomeVoiceStartRequested();
}

class HomeVoiceStopRequested extends HomeEvent {
  const HomeVoiceStopRequested();
}

class HomeVoiceAutoStopTriggered extends HomeEvent {
  const HomeVoiceAutoStopTriggered();
}

class HomeSpatialExploreUpdated extends HomeEvent {
  final int index;
  const HomeSpatialExploreUpdated(this.index);

  @override
  List<Object?> get props => [index];
}

class HomeSpatialExploreEnded extends HomeEvent {
  final int index;
  const HomeSpatialExploreEnded(this.index);

  @override
  List<Object?> get props => [index];
}

class HomeVoiceCommandReceived extends HomeEvent {
  final VoiceCommand command;
  const HomeVoiceCommandReceived(this.command);

  @override
  List<Object?> get props => [command];
}
