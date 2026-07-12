import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/nova_design_system.dart';
import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;
import '../bloc/ocr_bloc.dart';

class OcrPage extends StatelessWidget {
  const OcrPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OcrBloc>(),
      child: const _OcrView(),
    );
  }
}

class _OcrView extends StatefulWidget {
  const _OcrView();

  @override
  State<_OcrView> createState() => _OcrViewState();
}

class _OcrViewState extends State<_OcrView> {
  @override
  void initState() {
    super.initState();
    globalStopCurrentOption = () {
      if (mounted) context.read<OcrBloc>().add(const CancelOcrReading());
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final autoStart = ModalRoute.of(context)?.settings.arguments == true;
      if (autoStart) context.read<OcrBloc>().add(const TriggerOcr());
    });
  }

  @override
  void dispose() {
    globalStopCurrentOption = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OcrBloc, OcrState>(
      builder: (context, state) {
        final isBusy = state is OcrCapturing || state is OcrProcessing;

        return NovaScaffold(
          featureNumber: 2,
          title: 'Read Text',
          icon: Icons.document_scanner_rounded,
          semanticPageLabel:
              'Read Text page. Point the camera at printed text and press Capture.',
          body: Padding(
            padding: const EdgeInsets.all(kPagePad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: kGapM),

                NovaInstructionCard(
                  message: 'Point the camera at any printed text — a sign, document, or label — then press Capture.',
                  icon: Icons.camera_alt_rounded,
                  semanticLabel:
                      'Instruction: Point camera at text and press Capture.',
                ),

                const SizedBox(height: kGapM),

                // ── Primary action ────────────────────────────────────────────
                NovaBigButton(
                  label: 'Capture & Read',
                  icon: Icons.document_scanner_rounded,
                  enabled: !isBusy,
                  loading: isBusy,
                  semanticHint:
                      'Takes a photo and reads any text aloud',
                  onTap: () => context.read<OcrBloc>().add(const TriggerOcr()),
                ),

                const SizedBox(height: kGapS),

                // ── Stop reading ──────────────────────────────────────────────
                NovaOutlineButton(
                  label: 'Stop Reading',
                  icon: Icons.stop_circle_rounded,
                  borderColor: kNovaDanger,
                  foregroundColor: kNovaDanger,
                  semanticHint: 'Stops the current text-to-speech reading',
                  onTap: () => context.read<OcrBloc>().add(const CancelOcrReading()),
                ),

                const SizedBox(height: kGapM),

                // ── Content area ──────────────────────────────────────────────
                Expanded(child: _buildContent(state)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(OcrState state) {
    if (state is OcrCapturing) {
      return const NovaLoadingState(
          message: 'Capturing image.\nPlease hold the camera steady.');
    }
    if (state is OcrProcessing) {
      return const NovaLoadingState(message: 'Reading text from the image…');
    }
    if (state is OcrNoText) {
      return const NovaInfoState(
        icon: Icons.text_fields_rounded,
        message: 'No text detected.\nTry moving the camera closer and ensure good lighting.',
        iconColor: kNovaSecondary,
        semanticLabel:
            'No text detected. Move closer and try again.',
      );
    }
    if (state is OcrError) {
      return NovaInfoState(
        icon: Icons.error_outline_rounded,
        message: state.message,
        iconColor: kNovaDanger,
        semanticLabel: 'Error: ${state.message}',
      );
    }
    if (state is OcrReading) {
      return Semantics(
        liveRegion: true,
        label: 'Recognised text: ${state.text}',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RECOGNISED TEXT',
                style: TextStyle(
                  color: kNovaPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: kGapS),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(kGapM),
                decoration: BoxDecoration(
                  color: kNovaCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: kNovaPrimary.withValues(alpha: 0.25), width: 1.5),
                ),
                child: SelectableText(
                  state.text,
                  style: const TextStyle(
                    color: kNovaOnSurface,
                    fontSize: 19,
                    height: 1.65,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Idle
    return const NovaInfoState(
      icon: Icons.document_scanner_outlined,
      message: 'Press "Capture & Read" or say\n"read text" to begin.',
      semanticLabel: 'Ready. Press Capture and Read to begin.',
    );
  }
}
