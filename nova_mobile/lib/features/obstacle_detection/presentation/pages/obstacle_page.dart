import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/nova_design_system.dart';
import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;
import '../../domain/entities/obstacle_detection_result.dart';
import '../bloc/obstacle_bloc.dart';

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

class _ObstacleViewState extends State<_ObstacleView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

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
    _pulseCtrl.dispose();
    globalStopCurrentOption = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ObstacleBloc, ObstacleState>(
      builder: (context, state) {
        final detecting = state is ObstacleDetecting;
        final obstacles = detecting ? state.obstacles : const <DetectedObstacle>[];
        final hasError = state is ObstacleError;

        if (detecting && obstacles.isNotEmpty) {
          _pulseCtrl.repeat(reverse: true);
        } else {
          _pulseCtrl.stop();
          _pulseCtrl.reset();
        }

        return NovaScaffold(
          featureNumber: 1,
          title: 'Obstacle Detection',
          icon: Icons.warning_amber_rounded,
          semanticPageLabel:
              'Obstacle detection page. '
              '${detecting ? "Currently running. ${obstacles.length} obstacles detected." : "Currently stopped."}',
          onBack: () {
            context.read<ObstacleBloc>().add(const StopObstacleDetection());
            Navigator.pop(context);
          },
          statusBanner: NovaStatusBanner(
            isActive: detecting,
            activeLabel: 'Running — scanning your surroundings',
            idleLabel: 'Stopped — press Start to begin',
            activeColor: kNovaDanger,
            activeIcon: Icons.sensors_rounded,
            idleIcon: Icons.sensors_off_rounded,
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(kPagePad, kGapS, kPagePad, kPagePad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Error banner ──────────────────────────────────────────────
                if (hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: kGapS),
                    child: NovaResultCard(
                      icon: Icons.error_outline_rounded,
                      headline: (state as ObstacleError).message,
                      color: kNovaDanger,
                    ),
                  ),

                // ── Sonar / pulse indicator ───────────────────────────────────
                _SonarIndicator(
                  isActive: detecting,
                  hasObstacles: obstacles.isNotEmpty,
                  nearestZone: obstacles.isNotEmpty ? obstacles.first.zone : null,
                  pulseCtrl: _pulseCtrl,
                ),

                const SizedBox(height: kGapM),

                // ── Start / Stop ──────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: NovaBigButton(
                        label: 'Start',
                        icon: Icons.play_arrow_rounded,
                        enabled: !detecting,
                        semanticHint: 'Begin scanning your surroundings for obstacles. Walk carefully.',
                        onTap: () => context.read<ObstacleBloc>().add(const StartObstacleDetection()),
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
                        onTap: () => context.read<ObstacleBloc>().add(const StopObstacleDetection()),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: kGapM),

                // ── Obstacles list ────────────────────────────────────────────
                Expanded(
                  child: obstacles.isEmpty
                      ? _EmptyState(detecting: detecting)
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: obstacles.length,
                          itemBuilder: (context, i) {
                            final o = obstacles[i];
                            final desc =
                                '${o.label}, ${o.spokenDirection}, '
                                '${o.estimatedDistanceMeters.toStringAsFixed(1)} metres, '
                                '${o.zoneName} zone.';
                            return _ObstacleCard(obstacle: o, semanticDesc: desc);
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

// ── Sonar visual indicator ────────────────────────────────────────────────────
class _SonarIndicator extends StatelessWidget {
  final bool isActive;
  final bool hasObstacles;
  final ObstacleZone? nearestZone;
  final AnimationController pulseCtrl;

  const _SonarIndicator({
    required this.isActive,
    required this.hasObstacles,
    required this.nearestZone,
    required this.pulseCtrl,
  });

  Color get _zoneColor {
    if (!isActive) return kNovaSubtext;
    if (!hasObstacles) return kNovaPrimary;
    return switch (nearestZone) {
      ObstacleZone.near    => kNovaDanger,
      ObstacleZone.warning => kNovaSecondary,
      ObstacleZone.clear   => kNovaSuccess,
      _                    => kNovaPrimary,
    };
  }

  String get _centerLabel {
    if (!isActive) return 'STANDBY';
    if (!hasObstacles) return 'CLEAR';
    return switch (nearestZone) {
      ObstacleZone.near    => 'DANGER',
      ObstacleZone.warning => 'CAUTION',
      ObstacleZone.clear   => 'DETECTED',
      _                    => 'SCANNING',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, __) {
          final pulse = isActive && hasObstacles
              ? 0.4 + (pulseCtrl.value * 0.6)
              : 1.0;
          final col = _zoneColor;

          return Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: col.withValues(alpha: pulse * 0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                  // Mid ring
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: col.withValues(alpha: pulse * 0.5),
                        width: 1.5,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: col.withValues(alpha: 0.15 * pulse),
                                blurRadius: 20,
                                spreadRadius: 4,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  // Core
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: col.withValues(alpha: 0.12 * pulse),
                      border: Border.all(
                        color: col.withValues(alpha: pulse),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        isActive ? Icons.radar_rounded : Icons.sensors_off_rounded,
                        color: col.withValues(alpha: pulse),
                        size: 30,
                      ),
                    ),
                  ),
                  // Status label below
                  Positioned(
                    bottom: 10,
                    child: Text(
                      _centerLabel,
                      style: TextStyle(
                        color: col.withValues(alpha: pulse),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Obstacle card ─────────────────────────────────────────────────────────────
class _ObstacleCard extends StatelessWidget {
  final DetectedObstacle obstacle;
  final String semanticDesc;

  const _ObstacleCard({required this.obstacle, required this.semanticDesc});

  Color get _color => switch (obstacle.zone) {
        ObstacleZone.near    => kNovaDanger,
        ObstacleZone.warning => kNovaSecondary,
        ObstacleZone.clear   => kNovaSuccess,
        _                    => kNovaPrimary,
      };

  IconData get _icon => switch (obstacle.zone) {
        ObstacleZone.near    => Icons.warning_rounded,
        ObstacleZone.warning => Icons.report_problem_rounded,
        _                    => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final col = _color;
    return Semantics(
      label: semanticDesc,
      child: Container(
        margin: const EdgeInsets.only(bottom: kGapS),
        padding: const EdgeInsets.symmetric(horizontal: kGapS, vertical: 14),
        decoration: BoxDecoration(
          color: kNovaCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: col.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: col.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: col, size: 22),
            ),
            const SizedBox(width: kGapS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    obstacle.label.toUpperCase(),
                    style: TextStyle(
                      color: col,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${obstacle.spokenDirection}  •  ${obstacle.estimatedDistanceMeters.toStringAsFixed(1)} m',
                    style: const TextStyle(color: kNovaSubtext, fontSize: 13),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: col.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                obstacle.zoneName.toUpperCase(),
                style: TextStyle(
                  color: col,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool detecting;
  const _EmptyState({required this.detecting});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: detecting ? 'Scanning for obstacles. Path is clear.' : 'Stopped. Press Start to begin.',
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              detecting ? Icons.radar_rounded : Icons.sensors_off_rounded,
              size: 56,
              color: detecting ? kNovaPrimary.withValues(alpha: 0.5) : kNovaSubtext,
            ),
            const SizedBox(height: kGapM),
            Text(
              detecting ? 'Path is clear' : 'Press Start to begin scanning',
              style: TextStyle(
                color: detecting ? kNovaPrimary : kNovaSubtext,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (detecting) ...[
              const SizedBox(height: kGapS),
              Text(
                'NOVA is actively monitoring your surroundings',
                style: TextStyle(
                  color: kNovaSubtext.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
