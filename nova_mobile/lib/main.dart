import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'core/camera/camera_service.dart';
import 'core/constants/app_constants.dart';
import 'core/location/location_service.dart';
import 'core/settings/settings_service.dart';
import 'core/sync/sync_service.dart';
import 'core/tts/tts_service.dart';
import 'core/voice/voice_command_service.dart';
import 'features/currency_detection/presentation/pages/currency_page.dart';
import 'features/face_recognition/presentation/pages/face_enrolment_page.dart';
import 'features/face_recognition/presentation/pages/face_recognition_page.dart';
import 'features/home/presentation/pages/home_menu_page.dart';
import 'features/ocr/presentation/pages/ocr_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/obstacle_detection/presentation/pages/obstacle_page.dart';
import 'features/scene_description/presentation/pages/scene_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/splash/presentation/pages/splash_page.dart';
import 'package:url_launcher/url_launcher.dart';

import 'features/emergency_contact/presentation/pages/emergency_contact_page.dart';
import 'features/emergency_contact/domain/repositories/emergency_contact_repository.dart';
import 'features/emergency_contact/data/datasources/emergency_contact_datasource.dart';
import 'features/auth/presentation/auth_wrapper.dart';
import 'core/network/dio_client.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Run the splash FIRST, then initialise everything in the background.
  runApp(const NovaApp());
}

/// Background init — called by SplashPage while it is displayed.
Future<void> backgroundInit() async {
  await configureDependencies();

  // Quick health check — proceed in offline mode if it fails.
  try {
    await getIt<DioClient>().client
        .get(AppConstants.healthPath)
        .timeout(const Duration(seconds: 3));
    debugPrint('Backend /health check passed.');
  } catch (e) {
    debugPrint('Offline mode: $e');
  }

  // Pre-warm camera.
  if (!AppConstants.simulated) {
    try { await getIt<CameraService>().initialize(); } catch (_) {}
  }

  getIt<SyncService>().startWatching();
}

/// Global navigator key — used to route voice commands from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Current-page stop callback — each feature page registers its own.
VoidCallback? globalStopCurrentOption;

class NovaApp extends StatefulWidget {
  const NovaApp({super.key});

  @override
  State<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends State<NovaApp> {
  StreamSubscription<VoiceCommand>? _voiceSub;

  bool _locationQuerying = false;

  @override
  void initState() {
    super.initState();
    // Voice sub only available after init completes
    _initAndListen();
  }

  Future<void> _initAndListen() async {
    // Wait until getIt is ready (splash will have called backgroundInit)
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return !getIt.isRegistered<VoiceCommandRouter>();
    });
    _voiceSub = getIt<VoiceCommandRouter>().commands.listen(_handleVoiceCommand);
    _startContinuousListening();
  }

  void _startContinuousListening() {
    if (!getIt.isRegistered<VoiceCommandService>()) return;
    final svc = getIt<VoiceCommandService>();
    final lang = getIt<SettingsService>().language.value;
    svc.startListening(localeId: lang.replaceAll('-', '_'));
  }

  /// 🔒 Secret feature — triple-tap anywhere on the home screen
  /// to hear the current GPS location spoken aloud.
  Future<void> _announceLocation() async {
    if (_locationQuerying) return;
    _locationQuerying = true;
    if (!getIt.isRegistered<TtsService>()) return;
    final tts = getIt<TtsService>();
    await tts.speak('Finding your location…', priority: TtsPriority.high);
    try {
      final location = await LocationService().describeCurrentLocation();
      if (location != null) {
        await tts.speak(location, priority: TtsPriority.high);
      } else {
        await tts.speak(
          'I couldn\'t determine your location. Please make sure location is enabled.',
          priority: TtsPriority.high,
        );
      }
    } catch (_) {
      await tts.speak('Location unavailable right now.', priority: TtsPriority.high);
    } finally {
      _locationQuerying = false;
    }
  }

  @override
  void dispose() {
    _voiceSub?.cancel();
    super.dispose();
  }

  void _handleVoiceCommand(VoiceCommand command) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    const routes = [
      '/obstacle', '/ocr', '/scene', '/currency', '/faces', '/settings'
    ];

    void jumpTo(String route, {bool autoStart = true}) {
      Navigator.pushNamedAndRemoveUntil(
        ctx, route, ModalRoute.withName('/home'),
        arguments: autoStart,
      );
      // Re-arm listener after navigation
      Future.delayed(const Duration(milliseconds: 800), _startContinuousListening);
    }

    switch (command) {
      case VoiceCommand.option1:  jumpTo(routes[0]); break;
      case VoiceCommand.option2:  jumpTo(routes[1]); break;
      case VoiceCommand.option3:  jumpTo(routes[2]); break;
      case VoiceCommand.option4:  jumpTo(routes[3]); break;
      case VoiceCommand.option5:  jumpTo(routes[4]); break;
      case VoiceCommand.option6:  jumpTo(routes[5], autoStart: false); break;

      case VoiceCommand.stopCurrentOption:
        if (globalStopCurrentOption != null) {
          globalStopCurrentOption!();
        } else {
          getIt<TtsService>().stop();
        }
        _startContinuousListening();
        break;

      case VoiceCommand.slowTts:
        getIt<TtsService>().setSpeechRate(0.7);
        getIt<TtsService>().speak('Okay, I\'ll speak slower now.', priority: TtsPriority.normal);
        _startContinuousListening();
        break;
      case VoiceCommand.speedUpTts:
        getIt<TtsService>().setSpeechRate(1.4);
        getIt<TtsService>().speak('Alright, speaking faster now.', priority: TtsPriority.normal);
        _startContinuousListening();
        break;
      case VoiceCommand.stopTts:
        getIt<TtsService>().stop();
        _startContinuousListening();
        break;
      case VoiceCommand.confirm:
      case VoiceCommand.deny:
        // Handled directly by specific BLoCs via firstWhere.
        // We just re-arm the global listener here if it accidentally caught it.
        _startContinuousListening();
        break;
      case VoiceCommand.emergency:
        getIt<TtsService>().speak(
          'Emergency activated. Hold on.',
          priority: TtsPriority.critical,
          interrupt: true,
        );
        getIt<EmergencyContactRepository>().getContact().then((EmergencyContact? contact) async {
          if (contact != null && contact.phoneNumber.isNotEmpty) {
            final name = contact.contactName;
            getIt<TtsService>().speak(
              'Calling $name now. Stay calm.',
              priority: TtsPriority.critical,
              interrupt: true,
            );
            
            final uri = Uri.parse('tel:${contact.phoneNumber}');
            try {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                getIt<TtsService>().speak(
                  'I wasn\'t able to open the phone dialer. '
                  'Please ask someone nearby to call $name at ${contact.phoneNumber}.',
                  priority: TtsPriority.critical,
                );
              }
            } catch (_) {
              getIt<TtsService>().speak(
                'Something went wrong opening the dialer. '
                'Please ask someone to call $name at ${contact.phoneNumber}.',
                priority: TtsPriority.critical,
              );
            }
          } else {
            getIt<TtsService>().speak(
              'You don\'t have an emergency contact set up yet. '
              'Go to Settings, then tap Manage Emergency Contact to add one.',
              priority: TtsPriority.critical,
              interrupt: true,
            );
          }
        }).catchError((_) {
          getIt<TtsService>().speak(
            'I couldn\'t look up your emergency contact right now. '
            'Please ask someone nearby for help.',
            priority: TtsPriority.critical,
            interrupt: true,
          );
        });
        Future.delayed(const Duration(seconds: 2), _startContinuousListening);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'NOVA – Assistive Vision',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
          ),
        );
        return MediaQuery(
          data: MediaQuery.of(context),
          // Triple-tap anywhere to announce current location (secret feature)
          child: GestureDetector(
            onDoubleTap: null,
            onLongPress: null,
            behavior: HitTestBehavior.translucent,
            onTap: null,
            child: Listener(
              onPointerDown: null,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: null,
                // We use a custom triple-tap by stacking an invisible overlay
                child: Stack(
                  children: [
                    child!,
                    const _FloatingCameraOverlay(),
                    // Transparent triple-tap catcher at bottom-right corner
                    Positioned(
                      bottom: 0,
                      right: 0,
                      width: 60,
                      height: 60,
                      child: _TripleTapZone(onTripleTap: _announceLocation),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      home: SplashPage(initFuture: backgroundInit()),
      routes: {
        '/auth':      (_) => const AuthWrapper(),
        '/onboarding':(_) => const OnboardingPage(),
        '/home':      (_) => const HomeMenuPage(),
        '/obstacle':  (_) => const ObstaclePage(),
        '/ocr':       (_) => const OcrPage(),
        '/scene':     (_) => const ScenePage(),
        '/currency':  (_) => const CurrencyPage(),
        '/faces':     (_) => const FaceRecognitionPage(),
        '/settings':  (_) => const SettingsPage(),
        '/emergency': (_) => const EmergencyContactPage(),
        '/enrolment': (_) => const FaceEnrolmentPage(),
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Secret triple-tap zone \u2014 bottom-right 60x60 invisible hit zone
//  Triple-tap triggers GPS location announcement.
// ════════════════════════════════════════════════════════════════════════════
class _TripleTapZone extends StatefulWidget {
  final VoidCallback onTripleTap;
  const _TripleTapZone({required this.onTripleTap});

  @override
  State<_TripleTapZone> createState() => _TripleTapZoneState();
}

class _TripleTapZoneState extends State<_TripleTapZone> {
  int _tapCount = 0;
  DateTime? _firstTap;

  void _onTap() {
    final now = DateTime.now();
    if (_firstTap == null || now.difference(_firstTap!) > const Duration(seconds: 2)) {
      _firstTap = now;
      _tapCount = 1;
    } else {
      _tapCount++;
      if (_tapCount >= 3) {
        _tapCount = 0;
        _firstTap = null;
        widget.onTripleTap();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: const SizedBox(width: 60, height: 60),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Floating draggable camera overlay \u2014 visible on every screen when enabled
// ════════════════════════════════════════════════════════════════════════════
class _FloatingCameraOverlay extends StatefulWidget {
  const _FloatingCameraOverlay();

  @override
  State<_FloatingCameraOverlay> createState() => _FloatingCameraOverlayState();
}

class _FloatingCameraOverlayState extends State<_FloatingCameraOverlay>
    with SingleTickerProviderStateMixin {
  // Position (bottom-right corner by default)
  double _right = 12;
  double _bottom = 100;
  bool _minimised = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _waitForGetIt();
  }

  Future<void> _waitForGetIt() async {
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      return !getIt.isRegistered<SettingsService>();
    });
    if (mounted) setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return const SizedBox.shrink();

    return ValueListenableBuilder<bool>(
      valueListenable: getIt<SettingsService>().debugCameraPreview,
      builder: (_, showPreview, __) {
        if (!showPreview) return const SizedBox.shrink();

        final ctrl = getIt.isRegistered<CameraService>() ? getIt<CameraService>().controller : null;
        final hasRealCamera = ctrl != null && ctrl.value.isInitialized;

        return Positioned(
          right: _right,
          bottom: _bottom,
          child: GestureDetector(
            // Drag to reposition
            onPanUpdate: (details) => setState(() {
              _right  = (_right  - details.delta.dx).clamp(0.0, MediaQuery.of(context).size.width  - 130);
              _bottom = (_bottom - details.delta.dy).clamp(0.0, MediaQuery.of(context).size.height - 180);
            }),
            // Tap to minimise / maximise
            onTap: () => setState(() => _minimised = !_minimised),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: _minimised ? 48 : 130,
              height: _minimised ? 48 : 175,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(_minimised ? 24 : 14),
                border: Border.all(
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_minimised ? 22 : 12),
                child: _minimised
                    ? Center(
                        child: ScaleTransition(
                          scale: _pulseAnim,
                          child: const Icon(Icons.videocam_rounded,
                              color: Color(0xFF4FC3F7), size: 24),
                        ),
                      )
                    : hasRealCamera
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              // Actual live feed
                              _CameraPreviewWidget(ctrl: ctrl),
                              // Corner label
                              Positioned(
                                bottom: 4, left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Color(0xFF4FC3F7),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              // Drag hint icon
                              Positioned(
                                top: 4, right: 4,
                                child: Icon(Icons.open_with_rounded,
                                    size: 14, color: Colors.white38),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off_rounded,
                                  color: Colors.white54, size: 28),
                              const SizedBox(height: 4),
                              const Text(
                                'No cam',
                                style: TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Camera preview widget that handles aspect ratio ─────────────────────────
class _CameraPreviewWidget extends StatelessWidget {
  const _CameraPreviewWidget({required this.ctrl});
  final dynamic ctrl; // CameraController

  @override
  Widget build(BuildContext context) {
    try {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.previewSize?.height ?? 130,
          height: ctrl.value.previewSize?.width ?? 175,
          child: Builder(builder: (_) {
            // CameraPreview import is in obstacle_page.dart;
            // we import it here too via package:camera
            return _buildPreview(ctrl);
          }),
        ),
      );
    } catch (_) {
      return const Center(child: Icon(Icons.camera_alt, color: Colors.white38));
    }
  }

  Widget _buildPreview(dynamic ctrl) {
    // ignore: avoid_dynamic_calls
    return ctrl.buildPreview();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Theme — aligned with nova_design_system.dart constants
// ════════════════════════════════════════════════════════════════════════════
ThemeData _buildTheme() {
  // Exact token values mirrored from nova_design_system.dart
  const kPrimary   = Color(0xFF4FC3F7);
  const kSecondary = Color(0xFFFFCC02);
  const kDanger    = Color(0xFFFF5252);
  const kCard      = Color(0xFF1C2333);
  const kOnSurface = Color(0xFFF0F4F8);

  final cs = ColorScheme.fromSeed(
    seedColor: kPrimary,
    brightness: Brightness.dark,
    primary: kPrimary,
    onPrimary: Colors.black,
    secondary: kSecondary,
    onSecondary: Colors.black,
    error: kDanger,
    surface: Colors.black,       // pure black scaffold ← BVI requirement ≥7:1
    onSurface: kOnSurface,
    surfaceContainerHighest: kCard,
  );

  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.black,

    // ── Typography ──────────────────────────────────────────────────────────
    textTheme: const TextTheme(
      displayLarge:   TextStyle(fontSize: 48, fontWeight: FontWeight.bold,  letterSpacing: -0.5, color: kOnSurface),
      displayMedium:  TextStyle(fontSize: 36, fontWeight: FontWeight.bold,  color: kOnSurface),
      headlineLarge:  TextStyle(fontSize: 30, fontWeight: FontWeight.w700,  color: kOnSurface),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,  color: kOnSurface),
      titleLarge:     TextStyle(fontSize: 20, fontWeight: FontWeight.w600,  color: kOnSurface),
      titleMedium:    TextStyle(fontSize: 18, fontWeight: FontWeight.w500,  color: kOnSurface),
      bodyLarge:      TextStyle(fontSize: 18, height: 1.55,                 color: kOnSurface),
      bodyMedium:     TextStyle(fontSize: 16, height: 1.55,                 color: kOnSurface),
      labelLarge:     TextStyle(fontSize: 16, fontWeight: FontWeight.w600,  color: kOnSurface),
      bodySmall:      TextStyle(fontSize: 13, height: 1.4,                  color: Color(0xFFB0BEC5)),
    ),

    // ── ElevatedButton ──────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(72),   // matches kBigButtonHeight
        backgroundColor: kPrimary,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    ),

    // ── OutlinedButton ──────────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        foregroundColor: kPrimary,
        side: const BorderSide(color: kPrimary, width: 2),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),

    // ── FilledButton ────────────────────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(72),
        backgroundColor: kPrimary,
        foregroundColor: Colors.black,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: kCard,
      foregroundColor: kOnSurface,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.bold, color: kOnSurface),
    ),

    // ── Card ────────────────────────────────────────────────────────────────
    cardTheme: CardTheme(
      elevation: 0,
      color: kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),

    // ── Slider ──────────────────────────────────────────────────────────────
    sliderTheme: SliderThemeData(
      activeTrackColor: kPrimary,
      inactiveTrackColor: kCard,
      thumbColor: kPrimary,
      overlayColor: kPrimary.withValues(alpha: 0.2),
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
      trackHeight: 6,
    ),

    // ── Switch ──────────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? kPrimary : const Color(0xFF546E7A),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? kPrimary.withValues(alpha: 0.4)
            : kCard,
      ),
    ),

    // ── Divider ─────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: Color(0x22FFFFFF),
      thickness: 1,
    ),

    // ── InputDecoration ─────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kCard,
      labelStyle: const TextStyle(color: kPrimary),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.3), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: kPrimary.withValues(alpha: 0.3), width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: kPrimary, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
    ),

    // ── ProgressIndicator ───────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kPrimary,
      linearTrackColor: kCard,
    ),

    // ── Dialog ──────────────────────────────────────────────────────────────
    dialogTheme: DialogTheme(
      backgroundColor: kCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: kOnSurface),
      contentTextStyle: const TextStyle(
          fontSize: 16, color: Color(0xFFB0BEC5), height: 1.5),
    ),

    // ── Chip ────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: kCard,
      labelStyle: const TextStyle(color: kOnSurface, fontSize: 14),
      side: BorderSide(color: kPrimary.withValues(alpha: 0.3), width: 1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}


