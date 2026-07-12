import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/design/nova_design_system.dart';
import '../../../../core/tts/tts_service.dart';
import '../../../../injection_container.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> with SingleTickerProviderStateMixin {
  bool _requesting = false;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  static const _features = [
    (Icons.warning_amber_rounded, 'Obstacle Detection', 'Warns of objects in your path'),
    (Icons.document_scanner_rounded, 'Read Text', 'Reads printed text aloud'),
    (Icons.image_search_rounded, 'Describe Scene', 'Describes what the camera sees'),
    (Icons.payments_rounded, 'Identify Money', 'Identifies CFA franc notes'),
    (Icons.face_rounded, 'Recognize Faces', 'Names enrolled contacts'),
    (Icons.contact_emergency_rounded, 'Emergency Protocol', 'Calls for help when you say "Emergency"'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<TtsService>().speak(
        'Welcome to NOVA, your personal assistive companion. '
        'I can help you detect obstacles, read text, describe what\'s around you, '
        'identify money, and recognise faces. '
        'If you ever need help, just say "Emergency" from any screen '
        'and I\'ll call your emergency contact right away. '
        'Press the big button at the bottom to get started.',
        priority: TtsPriority.high,
      );
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestPermissionsAndGo() async {
    setState(() => _requesting = true);
    await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ].request();

    if (!AppConstants.simulated) {
      try {
        await getIt<CameraService>().initialize();
      } catch (_) {}
    }

    if (mounted) {
      setState(() => _requesting = false);
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              // ── Top hero area ──────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(kPagePad, kGapXL, kPagePad, kGapM),
                  child: Column(
                    children: [
                      // Logo glow
                      Semantics(
                        header: true,
                        label: 'NOVA — Navigational Object and Voice Assistant',
                        child: Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: kNovaPrimary.withValues(alpha: 0.15),
                                border: Border.all(color: kNovaPrimary, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: kNovaPrimary.withValues(alpha: 0.4),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.accessibility_new_rounded, size: 52, color: kNovaPrimary),
                            ),
                            const SizedBox(height: kGapM),
                            const Text(
                              'NOVA',
                              style: TextStyle(
                                color: kNovaOnSurface,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Navigational Object and Voice Assistant',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: kNovaSubtext, fontSize: 15, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: kGapXL),

                      // ── Feature list ─────────────────────────────────────────
                      ExcludeSemantics(
                        child: Column(
                          children: _features.map((f) {
                            final (icon, title, desc) = f;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: kGapS),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: kGapS, vertical: 10),
                                decoration: BoxDecoration(
                                  color: kNovaCard,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: kNovaPrimary.withValues(alpha: 0.15), width: 1),
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon, color: kNovaPrimary, size: 24),
                                    const SizedBox(width: kGapS),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, style: const TextStyle(color: kNovaOnSurface, fontSize: 15, fontWeight: FontWeight.w600)),
                                        Text(desc, style: const TextStyle(color: kNovaSubtext, fontSize: 13)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom action area ─────────────────────────────────────────
              Container(
                padding: EdgeInsets.fromLTRB(kPagePad, kGapM, kPagePad, kGapM + mq.padding.bottom),
                decoration: BoxDecoration(
                  color: kNovaCard,
                  border: const Border(top: BorderSide(color: kNovaPrimary, width: 1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MergeSemantics(
                      child: Semantics(
                        button: true,
                        label: 'Replay welcome message',
                        child: GestureDetector(
                          onTap: () => getIt<TtsService>().speak(
                            'Welcome to NOVA. Press the big button below to get started.',
                            priority: TtsPriority.high,
                            interrupt: true,
                          ),
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              border: Border.all(color: kNovaPrimary.withValues(alpha: 0.5), width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                              color: kNovaPrimary.withValues(alpha: 0.05),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.volume_up_rounded, color: kNovaPrimary, size: 22),
                                SizedBox(width: kGapXS),
                                Text('Replay Welcome', style: TextStyle(color: kNovaPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: kGapS),
                    NovaBigButton(
                      label: _requesting ? 'Requesting Permissions…' : 'Enter NOVA',
                      icon: _requesting ? Icons.hourglass_top_rounded : Icons.arrow_forward_rounded,
                      loading: _requesting,
                      semanticHint: 'Requests camera and microphone permissions then opens the main menu',
                      onTap: _requesting ? null : _requestPermissionsAndGo,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
