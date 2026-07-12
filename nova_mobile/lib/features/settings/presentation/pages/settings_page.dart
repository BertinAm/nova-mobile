import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/nova_design_system.dart';
import '../../../../core/settings/settings_service.dart';
import '../../../../core/tts/tts_service.dart';
import '../../../../injection_container.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../emergency_contact/domain/repositories/emergency_contact_repository.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsService _settings;
  late final TtsService _tts;

  late double _rate;
  late String _language;
  late bool _debugCamera;

  @override
  void initState() {
    super.initState();
    _settings    = getIt<SettingsService>();
    _tts         = getIt<TtsService>();
    _rate        = _settings.speechRate.value;
    _language    = _settings.language.value;
    _debugCamera = _settings.debugCameraPreview.value;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tts.speak('Settings page. Swipe up and down to explore your options.', priority: TtsPriority.normal);
    });
  }

  String get _rateLabel {
    if (_rate <= 0.6) return 'Very slow';
    if (_rate <= 0.85) return 'Slow';
    if (_rate <= 1.15) return 'Normal';
    if (_rate <= 1.4) return 'Fast';
    return 'Very fast';
  }

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      featureNumber: 6,
      title: 'Settings',
      icon: Icons.settings_rounded,
      semanticPageLabel: 'Settings page. Adjust speech speed, language, and manage your account.',
      body: ListView(
        padding: const EdgeInsets.all(kPagePad),
        children: [
          // ── Read settings aloud ─────────────────────────────────────────────
          NovaBigButton(
            label: 'Read Settings Aloud',
            icon: Icons.record_voice_over_rounded,
            color: kNovaCard,
            textColor: kNovaPrimary,
            semanticHint: 'Speaks a summary of all your current settings',
            onTap: _readSettingsAloud,
          ),

          const NovaDivider(),

          // ── Voice speed ─────────────────────────────────────────────────────
          const NovaSectionHeader('Voice Speed'),

          Semantics(
            label: 'Speech rate slider',
            value: _rateLabel,
            hint: 'Swipe left or right to adjust',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: kGapXS),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ExcludeSemantics(child: Text('Slower', style: TextStyle(color: kNovaSubtext, fontSize: 14))),
                      Text(
                        _rateLabel,
                        style: const TextStyle(color: kNovaPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      ExcludeSemantics(child: Text('Faster', style: TextStyle(color: kNovaSubtext, fontSize: 14))),
                    ],
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: kNovaPrimary,
                    inactiveTrackColor: kNovaCard,
                    thumbColor: kNovaPrimary,
                    overlayColor: kNovaPrimary.withValues(alpha: 0.2),
                    trackHeight: 6,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                  ),
                  child: Slider(
                    value: _rate,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    label: _rateLabel,
                    semanticFormatterCallback: (_) => _rateLabel,
                    onChanged: (value) => setState(() => _rate = value),
                    onChangeEnd: (value) async {
                      await _settings.setSpeechRate(value);
                      await _tts.setSpeechRate(value);
                      await _tts.speak('Speed set to $_rateLabel.', priority: TtsPriority.high);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: kGapS),

          // ── Speed presets ───────────────────────────────────────────────────
          Semantics(
            label: 'Speech rate presets',
            child: Row(
              children: [
                Expanded(child: _RatePresetButton(label: 'Slow',   rate: 0.7, currentRate: _rate, onTap: _setRate)),
                const SizedBox(width: kGapS),
                Expanded(child: _RatePresetButton(label: 'Normal', rate: 1.0, currentRate: _rate, onTap: _setRate)),
                const SizedBox(width: kGapS),
                Expanded(child: _RatePresetButton(label: 'Fast',   rate: 1.4, currentRate: _rate, onTap: _setRate)),
              ],
            ),
          ),

          const NovaDivider(),

          // ── Language ────────────────────────────────────────────────────────
          const NovaSectionHeader('Language'),

          _LanguageOption(
            code: 'en-CM', displayName: 'English',
            icon: Icons.language_rounded,
            selectedCode: _language,
            onSelect: (c) => _setLanguage(c, 'English selected.'),
          ),
          const SizedBox(height: kGapS),
          _LanguageOption(
            code: 'fr-CM', displayName: 'Français',
            icon: Icons.language_rounded,
            selectedCode: _language,
            onSelect: (c) => _setLanguage(c, 'Français sélectionné.'),
          ),

          const NovaDivider(),

          // ── Emergency Contact ───────────────────────────────────────────────
          const NovaSectionHeader('Safety'),

          NovaOutlineButton(
            label: 'Manage Emergency Contact',
            icon: Icons.contact_emergency_rounded,
            semanticHint: 'Opens emergency contact settings where you can add or change your emergency contact',
            onTap: () {
              Navigator.pushNamed(context, '/emergency');
            },
          ),

          const NovaDivider(),

          // ── Debug ───────────────────────────────────────────────────────────
          const NovaSectionHeader('Developer'),

          MergeSemantics(
            child: Semantics(
              label: 'Debug camera preview toggle',
              value: _debugCamera ? 'enabled' : 'disabled',
              hint: 'Double tap to toggle. Shows live camera feed in Obstacle Detection.',
              toggled: _debugCamera,
              child: GestureDetector(
                onTap: () async {
                  final val = !_debugCamera;
                  setState(() => _debugCamera = val);
                  await _settings.setDebugCameraPreview(val);
                  await _tts.speak('Camera preview ${val ? "turned on" : "turned off"}.', priority: TtsPriority.normal);
                },
                child: Container(
                  padding: const EdgeInsets.all(kGapS),
                  decoration: BoxDecoration(
                    color: kNovaCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _debugCamera ? kNovaPrimary.withValues(alpha: 0.4) : kNovaPrimary.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.videocam_outlined, color: _debugCamera ? kNovaPrimary : kNovaSubtext, size: 26),
                      const SizedBox(width: kGapS),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Camera Preview (Debug)',
                                style: TextStyle(color: _debugCamera ? kNovaOnSurface : kNovaSubtext, fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text('Shows live camera feed overlay', style: TextStyle(color: kNovaSubtext, fontSize: 13)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _debugCamera,
                        onChanged: null, // handled by GestureDetector above
                        activeColor: kNovaPrimary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const NovaDivider(),

          // ── Account ─────────────────────────────────────────────────────────
          const NovaSectionHeader('Account'),

          NovaOutlineButton(
            label: 'Log Out',
            icon: Icons.logout_rounded,
            borderColor: kNovaDanger,
            foregroundColor: kNovaDanger,
            semanticHint: 'Double tap to sign out of your account',
            onTap: () => _confirmLogout(context),
          ),

          const SizedBox(height: kGapXL),

          // ── Confirm ─────────────────────────────────────────────────────────
          NovaBigButton(
            label: 'Done',
            icon: Icons.check_circle_outline_rounded,
            semanticHint: 'Confirms your settings and goes back to the main menu',
            onTap: () {
              _tts.speak('Settings saved. Going back.', priority: TtsPriority.normal);
              Navigator.maybePop(context);
            },
          ),

          const SizedBox(height: kGapM),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text(
          'You will need to log in again to use cloud features like scene description '
          'and emergency contact sync. On-device features will still work.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _tts.speak('Logging you out. See you next time.', priority: TtsPriority.high, interrupt: true);
              // Pop all routes and navigate to auth
              Navigator.pushNamedAndRemoveUntil(context, '/auth', (_) => false);
              // Trigger logout in a new AuthBloc since we're outside the provider tree
              getIt<AuthBloc>()..add(const AuthLogoutRequested());
            },
            child: Text('Log Out', style: TextStyle(color: kNovaDanger)),
          ),
        ],
      ),
    );
  }

  Future<void> _setRate(double rate) async {
    setState(() => _rate = rate);
    await _settings.setSpeechRate(rate);
    await _tts.setSpeechRate(rate);
    await _tts.speak('Speed set to $_rateLabel.', priority: TtsPriority.high);
  }

  Future<void> _setLanguage(String code, String announcement) async {
    setState(() => _language = code);
    await _settings.setLanguage(code);
    await _tts.setLanguage(code);
    await _tts.speak(announcement, priority: TtsPriority.high);
  }

  Future<void> _readSettingsAloud() async {
    final langName = _language == 'fr-CM' ? 'Français' : 'English';
    
    String emergencyStatus = 'You don\'t have an emergency contact set up yet.';
    try {
      final contact = await getIt<EmergencyContactRepository>().getContact();
      if (contact != null) {
        emergencyStatus = 'Your emergency contact is ${contact.contactName}.';
      }
    } catch (_) {}

    _tts.speak(
      'Here are your current settings. '
      'Voice speed is $_rateLabel. '
      'Language is $langName. '
      'Camera preview is ${_debugCamera ? "on" : "off"}. '
      '$emergencyStatus',
      priority: TtsPriority.high,
      interrupt: true,
    );
  }
}

class _RatePresetButton extends StatelessWidget {
  const _RatePresetButton({
    required this.label,
    required this.rate,
    required this.currentRate,
    required this.onTap,
  });
  final String label;
  final double rate;
  final double currentRate;
  final Future<void> Function(double) onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = (currentRate - rate).abs() < 0.05;
    return Semantics(
      button: true,
      label: 'Set speech rate to $label',
      selected: isSelected,
      child: GestureDetector(
        onTap: () => onTap(rate),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isSelected ? kNovaPrimary.withValues(alpha: 0.2) : kNovaCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? kNovaPrimary : kNovaPrimary.withValues(alpha: 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? kNovaPrimary : kNovaSubtext,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.code,
    required this.displayName,
    required this.icon,
    required this.selectedCode,
    required this.onSelect,
  });
  final String code;
  final String displayName;
  final IconData icon;
  final String selectedCode;
  final Future<void> Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedCode == code;
    return MergeSemantics(
      child: Semantics(
        label: 'Language option: $displayName',
        selected: isSelected,
        hint: isSelected ? 'Currently selected' : 'Double tap to select',
        button: true,
        child: GestureDetector(
          onTap: () => onSelect(code),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: kGapM),
            decoration: BoxDecoration(
              color: isSelected ? kNovaPrimary.withValues(alpha: 0.15) : kNovaCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? kNovaPrimary : kNovaPrimary.withValues(alpha: 0.15),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? kNovaPrimary : kNovaSubtext, size: 22),
                const SizedBox(width: kGapS),
                Text(
                  displayName,
                  style: TextStyle(
                    color: isSelected ? kNovaOnSurface : kNovaSubtext,
                    fontSize: 18,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: kNovaPrimary, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
