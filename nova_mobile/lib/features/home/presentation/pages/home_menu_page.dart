import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design/nova_design_system.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/tts/tts_service.dart';
import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Menu item descriptor ─────────────────────────────────────────────────────
class _MenuItem {
  final int number;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String semanticHint;

  const _MenuItem({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.semanticHint,
  });
}

class HomeMenuPage extends StatefulWidget {
  const HomeMenuPage({super.key});

  @override
  State<HomeMenuPage> createState() => _HomeMenuPageState();
}

class _HomeMenuPageState extends State<HomeMenuPage> with WidgetsBindingObserver {
  static const _items = [
    _MenuItem(
      number: 1, title: 'Obstacle Detection',
      subtitle: 'Real-time path scanning',
      icon: Icons.warning_amber_rounded, accent: kNovaDanger,
      semanticHint: 'Option 1. Detects objects in your path and speaks directional alerts.',
    ),
    _MenuItem(
      number: 2, title: 'Read Text',
      subtitle: 'On-device OCR — offline',
      icon: Icons.document_scanner_rounded, accent: kNovaPrimary,
      semanticHint: 'Option 2. Points camera at printed text and reads it aloud.',
    ),
    _MenuItem(
      number: 3, title: 'Describe Scene',
      subtitle: 'AI scene caption — needs internet',
      icon: Icons.image_search_rounded, accent: const Color(0xFF4DB6AC),
      semanticHint: 'Option 3. Describes what the camera sees. Requires internet.',
    ),
    _MenuItem(
      number: 4, title: 'Identify Money',
      subtitle: 'CFA franc notes — offline',
      icon: Icons.payments_rounded, accent: kNovaSecondary,
      semanticHint: 'Option 4. Identifies CFA franc banknotes.',
    ),
    _MenuItem(
      number: 5, title: 'Recognize Faces',
      subtitle: 'Enrolled contacts — offline',
      icon: Icons.face_rounded, accent: const Color(0xFFCE93D8),
      semanticHint: 'Option 5. Recognizes and names enrolled contacts.',
    ),
    _MenuItem(
      number: 6, title: 'Settings',
      subtitle: 'Speech speed · Language · Debug',
      icon: Icons.settings_rounded, accent: kNovaSubtext,
      semanticHint: 'Option 6. Adjust speech rate, language, and accessibility options.',
    ),
  ];

  static const _routes = ['/obstacle', '/ocr', '/scene', '/currency', '/faces', '/settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    globalStopCurrentOption = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await [Permission.camera, Permission.microphone, Permission.location].request();
      if (!AppConstants.simulated) {
        try { await getIt<CameraService>().initialize(); } catch (_) {}
      }
      getIt<TtsService>().speak(
        'Welcome to the main menu. '
        'You have six options to choose from. '
        'Double tap anywhere to speak a command, '
        'or drag your finger up and down to explore.',
        priority: TtsPriority.normal,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) getIt<SyncService>().syncNow();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSpatialUpdate(BuildContext context, Offset localPosition, double totalHeight) {
    if (totalHeight <= 0) return;
    final idx = (localPosition.dy / totalHeight * _items.length).floor()
        .clamp(0, _items.length - 1);
    context.read<HomeBloc>().add(HomeSpatialExploreUpdated(idx));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeBloc>(
      create: (_) => getIt<HomeBloc>(),
      child: MultiBlocListener(
        listeners: [
          BlocListener<HomeBloc, HomeState>(
            listenWhen: (p, c) => c.navigationTarget != null,
            listener: (context, state) {
              if (state.navigationTarget != null) {
                Navigator.pushNamed(context, state.navigationTarget!, arguments: true);
              }
            },
          ),
        ],
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            final mq = MediaQuery.of(context);
            return Scaffold(
              backgroundColor: Colors.black,
              body: Column(
                children: [
                  // ── NOVA global header ──────────────────────────────────────
                  _NovaHomeHeader(
                    topPadding: mq.padding.top,
                    isListening: state.isListening,
                    onMicTap: () => context.read<HomeBloc>().add(
                      state.isListening
                          ? const HomeVoiceStopRequested()
                          : const HomeVoiceStartRequested(),
                    ),
                  ),

                  // ── Listening overlay or menu grid ──────────────────────────
                  Expanded(
                    child: state.isListening
                        ? _ListeningOverlay(
                            onStop: () => context.read<HomeBloc>().add(const HomeVoiceStopRequested()),
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final totalHeight = constraints.maxHeight;
                              return GestureDetector(
                                onDoubleTap: () => context.read<HomeBloc>().add(const HomeVoiceStartRequested()),
                                onVerticalDragUpdate: (d) => _onSpatialUpdate(context, d.localPosition, totalHeight),
                                onHorizontalDragUpdate: (d) => _onSpatialUpdate(context, d.localPosition, totalHeight),
                                onVerticalDragEnd: (_) {
                                  if (state.hoveredIndex != -1) {
                                    context.read<HomeBloc>().add(HomeSpatialExploreEnded(state.hoveredIndex));
                                  }
                                },
                                onHorizontalDragEnd: (_) {
                                  if (state.hoveredIndex != -1) {
                                    context.read<HomeBloc>().add(HomeSpatialExploreEnded(state.hoveredIndex));
                                  }
                                },
                                child: Column(
                                  children: List.generate(_items.length, (i) {
                                    final item      = _items[i];
                                    final isHovered = i == state.hoveredIndex;
                                    return Expanded(
                                      child: _MenuRow(
                                        item: item,
                                        isHovered: isHovered,
                                        onTap: () => Navigator.pushNamed(
                                            context, _routes[i], arguments: true),
                                      ),
                                    );
                                  }),
                                ),
                              );
                            },
                          ),
                  ),

                  // ── Bottom hint bar ─────────────────────────────────────────
                  _BottomHintBar(bottomPadding: mq.padding.bottom),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── NOVA home header ─────────────────────────────────────────────────────────
class _NovaHomeHeader extends StatelessWidget {
  const _NovaHomeHeader({
    required this.topPadding,
    required this.isListening,
    required this.onMicTap,
  });
  final double topPadding;
  final bool isListening;
  final VoidCallback onMicTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: topPadding + kGapS, bottom: kGapS, left: kGapM, right: kGapS),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF071019), Color(0xFF0D1117)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(bottom: BorderSide(color: kNovaPrimary, width: 1.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.accessibility_new_rounded, color: kNovaPrimary, size: 28),
          const SizedBox(width: kGapXS),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('NOVA', style: TextStyle(color: kNovaOnSurface, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text('Main Menu', style: TextStyle(color: kNovaSubtext, fontSize: 12, letterSpacing: 0.5)),
              ],
            ),
          ),
          // Mic button
          MergeSemantics(
            child: Semantics(
              button: true,
              label: isListening ? 'Stop voice command' : 'Start voice command',
              hint: 'Or double tap anywhere on the screen',
              child: GestureDetector(
                onTap: onMicTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isListening
                        ? kNovaPrimary.withValues(alpha: 0.3)
                        : kNovaPrimary.withValues(alpha: 0.1),
                    border: Border.all(
                      color: isListening ? kNovaPrimary : kNovaPrimary.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: kNovaPrimary,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Single menu row ──────────────────────────────────────────────────────────
class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.isHovered,
    required this.onTap,
  });
  final _MenuItem item;
  final bool isHovered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = item.accent;

    return MergeSemantics(
      child: Semantics(
        button: true,
        label: 'Option ${item.number}: ${item.title}',
        hint: item.semanticHint,
        selected: isHovered,
        onTap: onTap,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            decoration: BoxDecoration(
              color: isHovered
                  ? accent.withValues(alpha: 0.18)
                  : Colors.black,
              border: Border(
                left: BorderSide(
                  color: isHovered ? accent : Colors.transparent,
                  width: 4,
                ),
                bottom: BorderSide(
                  color: kNovaPrimary.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Number badge
                const SizedBox(width: kGapM),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isHovered ? accent : accent.withValues(alpha: 0.15),
                    border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.number}',
                    style: TextStyle(
                      color: isHovered ? Colors.black : accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),

                const SizedBox(width: kGapM),

                // Icon
                Icon(item.icon, color: isHovered ? accent : accent.withValues(alpha: 0.7), size: 32),

                const SizedBox(width: kGapS),

                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: isHovered ? kNovaOnSurface : kNovaOnSurface.withValues(alpha: 0.9),
                          fontSize: 19,
                          fontWeight: isHovered ? FontWeight.bold : FontWeight.w600,
                        ),
                      ),
                      Text(
                        item.subtitle,
                        style: TextStyle(
                          color: isHovered ? accent.withValues(alpha: 0.8) : kNovaSubtext,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  color: isHovered ? accent : kNovaSubtext.withValues(alpha: 0.4),
                  size: 24,
                ),
                const SizedBox(width: kGapS),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Voice listening overlay ──────────────────────────────────────────────────
class _ListeningOverlay extends StatefulWidget {
  const _ListeningOverlay({required this.onStop});
  final VoidCallback onStop;

  @override
  State<_ListeningOverlay> createState() => _ListeningOverlayState();
}

class _ListeningOverlayState extends State<_ListeningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onStop,
      child: Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kNovaPrimary.withValues(alpha: 0.15),
                    border: Border.all(color: kNovaPrimary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: kNovaPrimary.withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.mic_rounded, size: 60, color: kNovaPrimary),
                ),
              ),
              const SizedBox(height: kGapL),
              const Text(
                'Listening…',
                style: TextStyle(color: kNovaPrimary, fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: kGapS),
              const Text(
                'Say an option (one to six) or a feature name',
                style: TextStyle(color: kNovaSubtext, fontSize: 16),
              ),
              const SizedBox(height: kGapXL),
              Semantics(
                button: true,
                label: 'Stop listening',
                child: GestureDetector(
                  onTap: widget.onStop,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: kGapL, vertical: kGapS),
                    decoration: BoxDecoration(
                      border: Border.all(color: kNovaDanger, width: 1.5),
                      borderRadius: BorderRadius.circular(30),
                      color: kNovaDanger.withValues(alpha: 0.1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.stop_rounded, color: kNovaDanger, size: 20),
                        SizedBox(width: kGapXS),
                        Text('Stop', style: TextStyle(color: kNovaDanger, fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Bottom hint strip ────────────────────────────────────────────────────────
class _BottomHintBar extends StatelessWidget {
  const _BottomHintBar({required this.bottomPadding});
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: EdgeInsets.fromLTRB(kGapM, kGapXS, kGapM, kGapXS + bottomPadding),
        color: kNovaCard,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, color: kNovaSubtext, size: 14),
            SizedBox(width: 6),
            Text(
              'Double-tap anywhere for voice  •  Drag to explore',
              style: TextStyle(color: kNovaSubtext, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
