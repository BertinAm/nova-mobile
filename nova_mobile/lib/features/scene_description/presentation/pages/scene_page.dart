import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/nova_design_system.dart';
import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;
import '../bloc/scene_bloc.dart';

class ScenePage extends StatelessWidget {
  const ScenePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SceneBloc>(),
      child: const _SceneView(),
    );
  }
}

class _SceneView extends StatefulWidget {
  const _SceneView();

  @override
  State<_SceneView> createState() => _SceneViewState();
}

class _SceneViewState extends State<_SceneView> {
  @override
  void initState() {
    super.initState();
    globalStopCurrentOption = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final autoStart = ModalRoute.of(context)?.settings.arguments == true;
      if (autoStart) {
        context.read<SceneBloc>().add(const RequestSceneDescription());
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
    return BlocBuilder<SceneBloc, SceneState>(
      builder: (context, state) {
        final isBusy = state is SceneLoading;

        return NovaScaffold(
          featureNumber: 3,
          title: 'Describe Scene',
          icon: Icons.image_search_rounded,
          semanticPageLabel:
              'Describe scene page. Point camera at a scene and double tap anywhere on the screen, or press Describe Scene.',
          body: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: isBusy
                ? null
                : () => context.read<SceneBloc>().add(const RequestSceneDescription()),
            child: Padding(
              padding: const EdgeInsets.all(kPagePad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: kGapM),

                  // ── Network requirement notice ─────────────────────────────────
                  NovaInstructionCard(
                    message:
                        'Requires internet. Point the camera at your surroundings and double tap the screen or press Describe.',
                    icon: Icons.wifi_rounded,
                    semanticLabel:
                        'This feature requires an internet connection. Point camera at a scene and double tap the screen or press Describe.',
                  ),

                  const SizedBox(height: kGapM),

                  // ── Primary action ────────────────────────────────────────────
                  NovaBigButton(
                    label: 'Describe Scene',
                    icon: Icons.image_search_rounded,
                    enabled: !isBusy,
                    loading: isBusy,
                    semanticHint:
                        'Double tap to take a photo and get a spoken description. Requires internet.',
                    onTap: () => context
                        .read<SceneBloc>()
                        .add(const RequestSceneDescription()),
                  ),

                const SizedBox(height: kGapM),

                // ── Content area ──────────────────────────────────────────────
                Expanded(child: _buildContent(state)),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  Widget _buildContent(SceneState state) {
    if (state is SceneLoading) {
      return const NovaLoadingState(
          message: 'Describing the scene, please wait…');
    }

    if (state is SceneOfflineError) {
      return const NovaInfoState(
        icon: Icons.wifi_off_rounded,
        message: 'Scene description requires an internet connection.\nPlease try again when connected.',
        iconColor: kNovaDanger,
        semanticLabel:
            'Scene description requires an internet connection. Please try again when connected.',
      );
    }

    if (state is SceneError) {
      return const NovaInfoState(
        icon: Icons.cloud_off_rounded,
        message: 'Scene description is unavailable right now.\nPlease try again later.',
        iconColor: kNovaSecondary,
        semanticLabel:
            'Scene description is unavailable right now. Please try again later.',
      );
    }

    if (state is SceneLoaded) {
      return Semantics(
        liveRegion: true,
        label: 'Scene description: ${state.description}',
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SCENE DESCRIPTION',
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
                child: Text(
                  state.description,
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
      icon: Icons.image_search_outlined,
      message: 'Press "Describe Scene" or say\n"describe scene" to begin.',
      semanticLabel: 'Ready. Press Describe Scene to begin.',
    );
  }
}
