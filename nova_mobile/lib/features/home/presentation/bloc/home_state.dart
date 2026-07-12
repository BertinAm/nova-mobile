import 'package:equatable/equatable.dart';

class HomeState extends Equatable {
  final bool isListening;
  final int hoveredIndex;
  final String? navigationTarget;

  const HomeState({
    this.isListening = false,
    this.hoveredIndex = -1,
    this.navigationTarget,
  });

  HomeState copyWith({
    bool? isListening,
    int? hoveredIndex,
    String? navigationTarget,
    bool clearNavigation = false,
  }) {
    return HomeState(
      isListening: isListening ?? this.isListening,
      hoveredIndex: hoveredIndex ?? this.hoveredIndex,
      navigationTarget: clearNavigation ? null : (navigationTarget ?? this.navigationTarget),
    );
  }

  @override
  List<Object?> get props => [isListening, hoveredIndex, navigationTarget];
}
