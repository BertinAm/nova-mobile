import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/nova_design_system.dart';
import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;
import '../../domain/entities/obstacle_detection_result.dart';
import '../bloc/obstacle_bloc.dart';
import '../../../../core/camera/camera_service.dart';
import '../../../../core/settings/settings_service.dart';
import 'package:camera/camera.dart';

class ObstaclePage extends StatelessWidget {
  const ObstaclePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<ObstacleBloc>(),
      child: const _ObstacleView(),
    );
  }
}

class _ObstacleView extends StatefulWidget {
  const _ObstacleView();

  @override
  State<_ObstacleView> createState() => _ObstacleViewState();
}

class _ObstacleViewState extends State<_ObstacleView> {
  @override
  void initState() {
    super.initState();
    globalStopCurrentOption = () {
      if (mounted) context.read<ObstacleBloc>().add(const StopObstacleDetection());
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final autoStart = ModalRoute.of(context)?.settings.arguments == true;
      if (autoStart) {
        context.read<ObstacleBloc>().add(const StartObstacleDetection());
      }
    });
  }

  @override
  void dispose() {
    globalStopCurrentOption = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ObstacleBloc, ObstacleState>(
      builder: (context, state) {
        final detecting  = state is ObstacleDetecting;
        final obstacles  = detecting ? state.obstacles : const <DetectedObstacle>[];
        final hasError   = state is ObstacleError;

        return NovaScaffold(
          featureNumber: 1,
          title: 'Obstacle Detection',
          icon: Icons.warning_amber_rounded,
          semanticPageLabel:
              'Obstacle detection page. '
              '${detecting ? "Currently running." : "Currently stopped."}',
          onBack: () {
            context.read<ObstacleBloc>().add(const StopObstacleDetection());
            Navigator.pop(context);
          },
          statusBanner: NovaStatusBanner(
            isActive: detecting,
            activeLabel: 'Running — scanning for obstacles',
            idleLabel: 'Stopped — press Start to begin',
            activeColor: kNovaDanger,
            activeIcon: Icons.sensors_rounded,
            idleIcon: Icons.sensors_off_rounded,
          ),
          body: Padding(
            padding: const EdgeInsets.all(kPagePad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: kGapS),

                // ── Camera preview (debug) ────────────────────────────────────
                _CameraPreviewSection(),

                const SizedBox(height: kGapS),

                // ── Error state ───────────────────────────────────────────────
                if (state case ObstacleError(:final message))
                  Padding(
                    padding: const EdgeInsets.only(bottom: kGapS),
                    child: NovaResultCard(
                      icon: Icons.error_outline_rounded,
                      headline: message,
                      color: kNovaDanger,
                    ),
                  ),

                // ── Start / Stop ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: NovaBigButton(
                        label: 'Start',
                        icon: Icons.play_arrow_rounded,
                        enabled: !detecting,
                        semanticHint: 'Begin scanning your surroundings for obstacles',
                        onTap: () => context
                            .read<ObstacleBloc>()
                            .add(const StartObstacleDetection()),
                      ),
                    ),
                    const SizedBox(width: kGapS),
                    Expanded(
                      child: NovaOutlineButton(
                        label: 'Stop',
                        icon: Icons.stop_rounded,
                        enabled: detecting,
                        semanticHint: 'Stop obstacle detection',
                        borderColor: kNovaDanger,
                        foregroundColor: kNovaDanger,
                        onTap: () => context
                            .read<ObstacleBloc>()
                            .add(const StopObstacleDetection()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: kGapM),

                // ── Obstacles list ────────────────────────────────────────────
                Expanded(
                  child: obstacles.isEmpty
                      ? NovaInfoState(
                          icon: detecting
                              ? Icons.radar_rounded
                              : Icons.sensors_off_rounded,
                          message: detecting
                              ? 'Scanning your surroundings…'
                              : 'Press Start to begin scanning.',
                          iconColor: detecting ? kNovaPrimary : kNovaSubtext,
                          semanticLabel: detecting
                              ? 'Scanning for obstacles'
                              : 'Stopped. Press Start to begin.',
                        )
                      : ListView.builder(
                          itemCount: obstacles.length,
                          itemBuilder: (context, i) {
                            final o = obstacles[i];
                            final desc =
                                '${o.label} — ${o.spokenDirection}, '
                                '${o.estimatedDistanceMeters.toStringAsFixed(1)} metres, '
                                '${o.zoneName} zone.';
                            return NovaObstacleCard(
                              label: o.label,
                              direction: o.spokenDirection,
                              distance: o.estimatedDistanceMeters,
                              zone: o.zoneName,
                              confidence: o.confidence,
                              semanticDesc: desc,
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CameraPreviewSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: getIt<SettingsService>().debugCameraPreview,
      builder: (_, show, __) {
        if (!show) return const SizedBox.shrink();
        final ctrl = getIt<CameraService>().controller;
        if (ctrl == null || !ctrl.value.isInitialized) return const SizedBox.shrink();

        return Semantics(
          excludeSemantics: true,
          label: 'Live camera preview',
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kNovaPrimary.withValues(alpha: 0.4), width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(ctrl),
                  Positioned(
                    top: 8, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(color: kNovaPrimary, fontSize: 11,
                            fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
