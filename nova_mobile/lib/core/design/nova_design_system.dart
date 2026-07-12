/// NOVA Design System — shared layout primitives and styled widgets.
///
/// Every feature page in lib/features/**/presentation/pages/ imports this
/// file instead of repeating styling constants inline.  The language of NOVA
/// is:
///
///   • Pure-black scaffold backgrounds for WCAG AAA contrast (≥ 7:1).
///   • Sky-blue (#4FC3F7) primary accent — bright, distinguishable, never
///     confused with warning amber (#FFCC02) or danger red (#FF5252).
///   • A thin horizontal gradient band at the top of every page content area
///     ("brow") that names the feature and carries a number badge.
///   • Large touch targets (min 72 dp tall) for every primary action.
///   • MergeSemantics + label + hint on every interactive element.
///
/// There is intentionally *no* dependency on any BLoC or Service here.
/// Pure UI primitives only.
library nova_design_system;

import 'package:flutter/material.dart';

// ─── Brand colours (re-exported for use in pages) ────────────────────────────
const Color kNovaPrimary      = Color(0xFF4FC3F7); // sky blue
const Color kNovaSecondary    = Color(0xFFFFCC02); // amber
const Color kNovaDanger       = Color(0xFFFF5252); // red
const Color kNovaSuccess      = Color(0xFF00E676); // green
const Color kNovaSurface      = Color(0xFF0D1117); // near-black surface
const Color kNovaCard         = Color(0xFF1C2333); // card / app-bar surface
const Color kNovaOnSurface    = Color(0xFFF0F4F8); // primary text
const Color kNovaSubtext      = Color(0xFFB0BEC5); // secondary text

// ─── Spacing tokens ───────────────────────────────────────────────────────────
const double kGapXS = 6;
const double kGapS  = 12;
const double kGapM  = 20;
const double kGapL  = 28;
const double kGapXL = 40;
const double kPagePad = 20.0;
const double kBigButtonHeight = 72.0;

// ─────────────────────────────────────────────────────────────────────────────
/// Feature-page Scaffold wrapper that enforces the NOVA design shell:
///
/// • Black background.
/// • Gradient AppBar that shows [featureNumber] + [title].
/// • Optional persistent floating [statusBanner] below the AppBar.
/// • [body] fills the remaining space.
///
/// All feature pages must use this instead of plain [Scaffold].
class NovaScaffold extends StatelessWidget {
  const NovaScaffold({
    super.key,
    required this.featureNumber,
    required this.title,
    required this.icon,
    required this.body,
    this.statusBanner,
    this.onBack,
    this.semanticPageLabel,
  });

  final int featureNumber;
  final String title;
  final IconData icon;
  final Widget body;
  final Widget? statusBanner;
  final VoidCallback? onBack;
  final String? semanticPageLabel;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Semantics(
      label: semanticPageLabel ?? 'NOVA feature: $title',
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          children: [
            // ── Gradient header brow ──────────────────────────────────────────
            _NovaHeader(
              featureNumber: featureNumber,
              title: title,
              icon: icon,
              topPadding: mq.padding.top,
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),

            // ── Optional status banner ────────────────────────────────────────
            if (statusBanner != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(kPagePad, kGapXS, kPagePad, 0),
                child: statusBanner!,
              ),

            // ── Feature body ──────────────────────────────────────────────────
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

// ─── Private header ───────────────────────────────────────────────────────────
class _NovaHeader extends StatelessWidget {
  const _NovaHeader({
    required this.featureNumber,
    required this.title,
    required this.icon,
    required this.topPadding,
    required this.onBack,
  });

  final int featureNumber;
  final String title;
  final IconData icon;
  final double topPadding;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
          top: topPadding + kGapS, bottom: kGapS, left: kGapS, right: kGapM),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1C2E), Color(0xFF0D1117)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(color: kNovaPrimary, width: 1.5),
        ),
      ),
      child: Row(
        children: [
          // Back arrow
          Semantics(
            button: true,
            label: 'Back to main menu',
            child: GestureDetector(
              onTap: onBack,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kNovaPrimary.withValues(alpha: 0.4), width: 1.5),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: kNovaPrimary, size: 20),
              ),
            ),
          ),

          const SizedBox(width: kGapS),

          // Number badge
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: kNovaPrimary,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$featureNumber',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),

          const SizedBox(width: kGapS),

          // Icon + title
          Icon(icon, color: kNovaPrimary, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: kNovaOnSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// A large, full-width primary action button.
/// Minimum height: 72 dp. Fully accessible with [label] and [hint].
class NovaBigButton extends StatelessWidget {
  const NovaBigButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.semanticHint,
    this.enabled = true,
    this.loading = false,
    this.color,
    this.textColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticHint;
  final bool enabled;
  final bool loading;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final bg     = color ?? kNovaPrimary;
    final fg     = textColor ?? Colors.black;
    final active = enabled && !loading;

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: active,
        label: label,
        hint: semanticHint,
        child: GestureDetector(
          onTap: active ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: active ? 1.0 : 0.45,
            child: Container(
              width: double.infinity,
              height: kBigButtonHeight,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: active
                    ? [BoxShadow(color: bg.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)]
                    : null,
              ),
              child: loading
                  ? Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: fg,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(icon, color: fg, size: 28),
                        const SizedBox(width: kGapS),
                        Text(
                          label,
                          style: TextStyle(
                            color: fg,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Secondary outlined button — same height as [NovaBigButton].
class NovaOutlineButton extends StatelessWidget {
  const NovaOutlineButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.semanticHint,
    this.enabled = true,
    this.borderColor,
    this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final String? semanticHint;
  final bool enabled;
  final Color? borderColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final col = borderColor ?? kNovaPrimary;
    final fg  = foregroundColor ?? kNovaPrimary;

    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        hint: semanticHint,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1.0 : 0.45,
            child: Container(
              width: double.infinity,
              height: kBigButtonHeight,
              decoration: BoxDecoration(
                border: Border.all(color: col, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: col.withValues(alpha: 0.08),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: fg, size: 26),
                  const SizedBox(width: kGapS),
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Status pill — the coloured banner below the header that shows running / idle.
class NovaStatusBanner extends StatelessWidget {
  const NovaStatusBanner({
    super.key,
    required this.isActive,
    required this.activeLabel,
    required this.idleLabel,
    this.activeColor = kNovaPrimary,
    this.idleColor   = kNovaCard,
    this.activeIcon  = Icons.sensors_rounded,
    this.idleIcon    = Icons.sensors_off_rounded,
  });

  final bool isActive;
  final String activeLabel;
  final String idleLabel;
  final Color activeColor;
  final Color idleColor;
  final IconData activeIcon;
  final IconData idleIcon;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : idleColor;
    final icon  = isActive ? activeIcon  : idleIcon;
    final label = isActive ? activeLabel : idleLabel;

    return Semantics(
      liveRegion: true,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: kGapM, vertical: kGapS),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: kGapS),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isActive)
              _PulsingDot(color: color),
          ],
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Centred informational state widget (idle / error / offline / no-data).
class NovaInfoState extends StatelessWidget {
  const NovaInfoState({
    super.key,
    required this.icon,
    required this.message,
    this.semanticLabel,
    this.iconColor,
  });

  final IconData icon;
  final String message;
  final String? semanticLabel;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: semanticLabel ?? message,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(kGapL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 72, color: iconColor ?? kNovaPrimary.withValues(alpha: 0.6)),
              const SizedBox(height: kGapM),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: kNovaSubtext,
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Loading spinner with spoken [message].
class NovaLoadingState extends StatelessWidget {
  const NovaLoadingState({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                color: kNovaPrimary,
              ),
            ),
            const SizedBox(height: kGapM),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kNovaSubtext,
                fontSize: 18,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Result card used by Currency and Face Recognition.
class NovaResultCard extends StatelessWidget {
  const NovaResultCard({
    super.key,
    required this.icon,
    required this.headline,
    this.subline,
    this.color = kNovaSuccess,
    this.semanticLabel,
  });

  final IconData icon;
  final String headline;
  final String? subline;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: semanticLabel ?? headline,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(kGapM),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(width: kGapM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    headline,
                    style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subline != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subline!,
                      style: const TextStyle(
                        color: kNovaSubtext,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Section label (e.g. "Enrolled Contacts") used inside scrollable pages.
class NovaSectionHeader extends StatelessWidget {
  const NovaSectionHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: kGapL, bottom: kGapS),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: kNovaPrimary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Instruction banner — short text in a muted card below a header.
class NovaInstructionCard extends StatelessWidget {
  const NovaInstructionCard({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.semanticLabel,
  });

  final String message;
  final IconData icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(kGapS),
        decoration: BoxDecoration(
          color: kNovaCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kNovaPrimary.withValues(alpha: 0.2), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: kNovaPrimary.withValues(alpha: 0.7), size: 20),
            const SizedBox(width: kGapS),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: kNovaSubtext,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Divider line used between sections on scrollable pages.
class NovaDivider extends StatelessWidget {
  const NovaDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: kGapM),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            kNovaPrimary.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
/// Obstacle detection card — colour-coded by zone severity.
class NovaObstacleCard extends StatelessWidget {
  const NovaObstacleCard({
    super.key,
    required this.label,
    required this.direction,
    required this.distance,
    required this.zone,
    required this.confidence,
    required this.semanticDesc,
  });

  final String label;
  final String direction;
  final double distance;
  final String zone;
  final double confidence;
  final String semanticDesc;

  @override
  Widget build(BuildContext context) {
    final isNear    = zone == 'near';
    final isWarning = zone == 'warning';
    final color = isNear
        ? kNovaDanger
        : isWarning
            ? kNovaSecondary
            : kNovaPrimary;

    return Semantics(
      liveRegion: true,
      label: semanticDesc,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(kGapM),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Row(
          children: [
            Icon(
              isNear ? Icons.warning_rounded : Icons.warning_amber_rounded,
              color: color,
              size: 36,
            ),
            const SizedBox(width: kGapS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label — $direction',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${distance.toStringAsFixed(1)} m · $zone zone · ${(confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: kNovaSubtext,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
