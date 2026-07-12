import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/nova_design_system.dart';
import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;
import '../bloc/currency_bloc.dart';

class CurrencyPage extends StatelessWidget {
  const CurrencyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<CurrencyBloc>(),
      child: const _CurrencyView(),
    );
  }
}

class _CurrencyView extends StatefulWidget {
  const _CurrencyView();

  @override
  State<_CurrencyView> createState() => _CurrencyViewState();
}

class _CurrencyViewState extends State<_CurrencyView> {
  @override
  void initState() {
    super.initState();
    globalStopCurrentOption = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final autoStart = ModalRoute.of(context)?.settings.arguments == true;
      if (autoStart) context.read<CurrencyBloc>().add(const IdentifyCurrency());
    });
  }

  @override
  void dispose() {
    globalStopCurrentOption = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CurrencyBloc, CurrencyState>(
      builder: (context, state) {
        final isBusy = state is CurrencyProcessing;

        return NovaScaffold(
          featureNumber: 4,
          title: 'Identify Money',
          icon: Icons.payments_rounded,
          semanticPageLabel:
              'Identify Money page. Hold a CFA franc banknote flat in front of the camera and double tap anywhere on the screen, or press the Identify button.',
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: isBusy
                ? null
                : () => context.read<CurrencyBloc>().add(const IdentifyCurrency()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Content area (result or idle) ─────────────────────────────
                Expanded(child: _buildContent(state)),

                // ── Fixed bottom action panel ─────────────────────────────────
                _ActionPanel(isBusy: isBusy),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(CurrencyState state) {
    if (state is CurrencyProcessing) {
      return const _ScanningView();
    }

    if (state is CurrencyDetected) {
      return _DetectedView(state: state);
    }

    if (state is CurrencyNotClear) {
      return _NotClearView(state: state);
    }

    if (state is CurrencyError) {
      return NovaInfoState(
        icon: Icons.error_outline_rounded,
        message: state.message,
        iconColor: kNovaDanger,
        semanticLabel: 'Error: ${state.message}',
      );
    }

    // Idle
    return const _IdleView();
  }
}

// ─── Action panel (always pinned at bottom) ───────────────────────────────────
class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.isBusy});
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(kPagePad, kGapS, kPagePad, kGapS + bottom),
      decoration: BoxDecoration(
        color: kNovaCard,
        border: const Border(top: BorderSide(color: kNovaPrimary, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instruction strip
          Semantics(
            label: 'Hold a CFA franc banknote flat in front of the camera in good lighting, then press Identify.',
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    color: kNovaSecondary, size: 18),
                const SizedBox(width: kGapXS),
                Expanded(
                  child: Text(
                    'Hold note flat in front of camera with good lighting',
                    style: const TextStyle(
                        color: kNovaSubtext, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: kGapS),
          NovaBigButton(
            label: 'Identify Money',
            icon: Icons.payments_rounded,
            enabled: !isBusy,
            loading: isBusy,
            semanticHint: 'Takes a photo and identifies the CFA franc denomination',
            onTap: () =>
                context.read<CurrencyBloc>().add(const IdentifyCurrency()),
          ),
        ],
      ),
    );
  }
}

// ─── Idle view ────────────────────────────────────────────────────────────────
class _IdleView extends StatelessWidget {
  const _IdleView();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ready. Press Identify Money to begin.',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(kGapL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Stylised coin graphic
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kNovaSecondary.withValues(alpha: 0.08),
                  border: Border.all(
                      color: kNovaSecondary.withValues(alpha: 0.4), width: 2),
                ),
                child: const Icon(Icons.payments_rounded,
                    size: 60, color: kNovaSecondary),
              ),
              const SizedBox(height: kGapM),
              const Text(
                'Hold a CFA franc banknote\nin front of the camera',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: kNovaOnSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.4),
              ),
              const SizedBox(height: kGapS),
              const Text(
                'Then press the button below',
                textAlign: TextAlign.center,
                style: TextStyle(color: kNovaSubtext, fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Scanning / processing view ───────────────────────────────────────────────
class _ScanningView extends StatefulWidget {
  const _ScanningView();

  @override
  State<_ScanningView> createState() => _ScanningViewState();
}

class _ScanningViewState extends State<_ScanningView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Processing the note. Please hold steady.',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _anim,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kNovaPrimary.withValues(alpha: 0.12),
                  border: Border.all(color: kNovaPrimary, width: 2.5),
                ),
                child: const Icon(Icons.document_scanner_rounded,
                    size: 56, color: kNovaPrimary),
              ),
            ),
            const SizedBox(height: kGapM),
            const Text('Processing the note…',
                style: TextStyle(
                    color: kNovaPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: kGapXS),
            const Text('Please hold steady',
                style: TextStyle(color: kNovaSubtext, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// ─── Detection success view ───────────────────────────────────────────────────
class _DetectedView extends StatelessWidget {
  const _DetectedView({required this.state});
  final CurrencyDetected state;

  @override
  Widget build(BuildContext context) {
    final label      = state.result.spokenLabel ?? 'Unknown denomination';
    final confidence = (state.result.confidence * 100).round();

    return Semantics(
      liveRegion: true,
      label: 'Detected: $label. Confidence $confidence percent.',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(kGapL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Denomination banner ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: kGapL, horizontal: kGapM),
                decoration: BoxDecoration(
                  color: kNovaSuccess.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: kNovaSuccess.withValues(alpha: 0.6), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: kNovaSuccess.withValues(alpha: 0.15),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: kNovaSuccess, size: 56),
                    const SizedBox(height: kGapS),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kNovaSuccess,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: kGapM),

              // ── Confidence bar ────────────────────────────────────────────
              Semantics(
                label: 'Confidence: $confidence percent',
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Confidence',
                            style: TextStyle(
                                color: kNovaSubtext,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                        Text(
                          '$confidence%',
                          style: TextStyle(
                            color: confidence >= 80
                                ? kNovaSuccess
                                : confidence >= 60
                                    ? kNovaSecondary
                                    : kNovaDanger,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kGapXS),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: confidence / 100.0,
                        minHeight: 10,
                        backgroundColor: kNovaCard,
                        color: confidence >= 80
                            ? kNovaSuccess
                            : confidence >= 60
                                ? kNovaSecondary
                                : kNovaDanger,
                      ),
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

// ─── Not clear view ───────────────────────────────────────────────────────────
class _NotClearView extends StatelessWidget {
  const _NotClearView({required this.state});
  final CurrencyNotClear state;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Could not identify the note clearly. Please try again with better lighting.',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(kGapL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: kGapL, horizontal: kGapM),
                decoration: BoxDecoration(
                  color: kNovaSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                      color: kNovaSecondary.withValues(alpha: 0.5), width: 2.5),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: kNovaSecondary, size: 56),
                    const SizedBox(height: kGapS),
                    const Text(
                      'Could not identify the note clearly',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: kNovaSecondary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: kGapS),
                    const Text(
                      'Try moving closer or improving lighting',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kNovaSubtext, fontSize: 15, height: 1.4),
                    ),
                  ],
                ),
              ),

              if (state.underExposed) ...[
                const SizedBox(height: kGapM),
                Container(
                  padding: const EdgeInsets.all(kGapS),
                  decoration: BoxDecoration(
                    color: kNovaPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: kNovaPrimary.withValues(alpha: 0.3), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.flashlight_on_rounded,
                          color: kNovaPrimary, size: 22),
                      SizedBox(width: kGapS),
                      Expanded(
                        child: Text(
                          'Tip: Turn on your torch for better lighting',
                          style: TextStyle(
                              color: kNovaPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
