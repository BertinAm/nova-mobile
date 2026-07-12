import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/design/nova_design_system.dart';

/// Splash screen shown while NOVA initialises all background services.
/// Replaced by [AuthWrapper] once [initFuture] completes.
class SplashPage extends StatefulWidget {
  final Future<void> initFuture;

  const SplashPage({super.key, required this.initFuture});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _ring;

  String _statusText = 'Initialising…';

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _opacity = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ring = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _boot();
  }

  Future<void> _boot() async {
    final steps = [
      'Loading language models…',
      'Configuring camera…',
      'Preparing voice engine…',
      'Syncing with server…',
      'Almost ready…',
    ];

    // Kick off the real init in parallel with showing messages
    final initFuture = widget.initFuture;
    final stepDuration = const Duration(milliseconds: 900);

    for (final step in steps) {
      if (!mounted) return;
      setState(() => _statusText = step);
      await Future.delayed(stepDuration);
    }

    // Wait for actual init to complete
    await initFuture;

    if (!mounted) return;
    // Navigate to auth which decides login vs home
    Navigator.of(context).pushReplacementNamed('/auth');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Pulsing ring + logo ─────────────────────────────────────
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kNovaPrimary.withValues(alpha: _ring.value),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: kNovaPrimary.withValues(alpha: _ring.value * 0.4),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    // Inner ring
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kNovaPrimary.withValues(alpha: _ring.value * 0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    // Logo container
                    Transform.scale(
                      scale: _scale.value,
                      child: Opacity(
                        opacity: _opacity.value,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                kNovaPrimary.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.remove_red_eye_rounded,
                            color: kNovaPrimary,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // ── Brand name ──────────────────────────────────────────────
                Opacity(
                  opacity: _opacity.value,
                  child: const Text(
                    'NOVA',
                    style: TextStyle(
                      color: kNovaPrimary,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 10,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Navigational Object & Voice Assistant',
                  style: TextStyle(
                    color: kNovaSubtext.withValues(alpha: 0.8),
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 56),

                // ── Loading indicator + status ──────────────────────────────
                SizedBox(
                  width: 220,
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        backgroundColor: kNovaCard,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          kNovaPrimary.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _statusText,
                        style: const TextStyle(
                          color: kNovaSubtext,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
