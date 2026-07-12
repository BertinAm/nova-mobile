import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/nova_design_system.dart';
import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;
import '../bloc/face_bloc.dart';

class FaceRecognitionPage extends StatelessWidget {
  const FaceRecognitionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<FaceBloc>()..add(const LoadContacts()),
      child: const _FaceView(),
    );
  }
}

class _FaceView extends StatefulWidget {
  const _FaceView();

  @override
  State<_FaceView> createState() => _FaceViewState();
}

class _FaceViewState extends State<_FaceView> {
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    globalStopCurrentOption = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final autoStart = ModalRoute.of(context)?.settings.arguments == true;
      if (autoStart) context.read<FaceBloc>().add(const RecogniseFace());
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    globalStopCurrentOption = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FaceBloc, FaceState>(
      builder: (context, state) {
        final contacts  = state is FaceReady ? state.contacts : const [];
        final isLoading = state is FaceLoading;
        final hasError  = state is FaceError;
        final hasResult = state is FaceReady && state.lastResult != null;

        return NovaScaffold(
          featureNumber: 5,
          title: 'Recognize Faces',
          icon: Icons.face_rounded,
          semanticPageLabel: 'Recognize Faces page.',
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(kPagePad),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: kGapM),
                    NovaBigButton(
                      label: 'Who is this?',
                      icon: Icons.face_rounded,
                      loading: isLoading,
                      semanticHint: 'Points the camera at a person and speaks their name if enrolled',
                      onTap: () => context.read<FaceBloc>().add(const RecogniseFace()),
                    ),
                    const SizedBox(height: kGapM),
                    if (hasError)
                      Padding(
                        padding: const EdgeInsets.only(bottom: kGapM),
                        child: NovaResultCard(
                          icon: Icons.error_outline_rounded,
                          headline: (state as FaceError).message,
                          color: kNovaDanger,
                        ),
                      ),
                    if (hasResult) ...[
                      _FaceResultCard(state: state as FaceReady),
                      const SizedBox(height: kGapM),
                    ],
                    const NovaDivider(),
                    const NovaSectionHeader('Enrol a Contact'),
                    const NovaInstructionCard(
                      message: 'A caregiver can enrol known contacts here. The blind user can then say "who is this?" to recognise them later.',
                      icon: Icons.person_add_rounded,
                    ),
                    const SizedBox(height: kGapM),
                    MergeSemantics(
                      child: Semantics(
                        label: 'Contact name for enrolment',
                        hint: 'Type the name of the person to enrol',
                        textField: true,
                        child: TextField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          style: const TextStyle(color: kNovaOnSurface, fontSize: 18),
                          decoration: InputDecoration(
                            labelText: 'Contact name',
                            hintText: 'e.g. Mama, Doctor Mbarga…',
                            labelStyle: const TextStyle(color: kNovaPrimary),
                            hintStyle: TextStyle(color: kNovaSubtext.withValues(alpha: 0.6)),
                            prefixIcon: const Icon(Icons.person_outline, color: kNovaPrimary),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: kNovaPrimary.withValues(alpha: 0.4), width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: kNovaPrimary, width: 2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: kNovaCard,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: kGapS),
                    NovaOutlineButton(
                      label: 'Enrol Contact',
                      icon: Icons.person_add_rounded,
                      semanticHint: 'Captures face photos and saves this contact',
                      onTap: () {
                        final name = _nameController.text.trim();
                        if (name.isNotEmpty) {
                          context.read<FaceBloc>().add(EnrollContact(name));
                          _nameController.clear();
                        }
                      },
                    ),
                    const NovaDivider(),
                    NovaSectionHeader('Enrolled Contacts (${contacts.length})'),
                    if (contacts.isEmpty)
                      const NovaInfoState(
                        icon: Icons.people_outline_rounded,
                        message: 'No contacts enrolled yet.\nUse the form above to enrol someone.',
                        semanticLabel: 'No contacts enrolled.',
                      ),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(kPagePad, 0, kPagePad, kPagePad),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final contact = contacts[i];
                      final dateStr = contact.createdAt.toLocal().toString().split(' ').first;
                      return Semantics(
                        label: '${contact.name}, enrolled $dateStr',
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(kGapS),
                          decoration: BoxDecoration(
                            color: kNovaCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kNovaPrimary.withValues(alpha: 0.2), width: 1),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: kNovaPrimary.withValues(alpha: 0.2),
                                child: Text(
                                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: kNovaPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: kGapS),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(contact.name, style: const TextStyle(color: kNovaOnSurface, fontSize: 18, fontWeight: FontWeight.w600)),
                                    Text('Enrolled $dateStr', style: const TextStyle(color: kNovaSubtext, fontSize: 13)),
                                  ],
                                ),
                              ),
                              MergeSemantics(
                                child: Semantics(
                                  button: true,
                                  label: 'Delete ${contact.name}',
                                  child: GestureDetector(
                                    onTap: () => _confirmDelete(context, contact),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: kNovaDanger.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.delete_outline_rounded, color: kNovaDanger, size: 22),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: contacts.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, dynamic contact) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kNovaCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete contact?', style: TextStyle(color: kNovaOnSurface, fontWeight: FontWeight.bold)),
        content: Text('Delete ${contact.name} and their face data? This cannot be undone.', style: const TextStyle(color: kNovaSubtext)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: kNovaPrimary)),
          ),
          Semantics(
            button: true,
            label: 'Confirm delete ${contact.name}',
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kNovaDanger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx, true);
                context.read<FaceBloc>().add(DeleteContact(contact.id));
              },
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceResultCard extends StatelessWidget {
  const _FaceResultCard({required this.state});
  final FaceReady state;

  @override
  Widget build(BuildContext context) {
    final result = state.lastResult!;
    if (!result.faceDetected) return const SizedBox.shrink();
    if (result.matched) {
      final pct = ((result.similarity ?? 0) * 100).toStringAsFixed(0);
      return NovaResultCard(
        icon: Icons.check_circle_rounded,
        headline: 'Recognised: ${result.contactName}',
        subline: 'Similarity $pct%',
        color: kNovaSuccess,
        semanticLabel: 'Recognised ${result.contactName}. Similarity $pct percent.',
      );
    }
    return const NovaResultCard(
      icon: Icons.help_outline_rounded,
      headline: 'Unknown person detected.',
      color: kNovaSecondary,
      semanticLabel: 'Unknown person detected.',
    );
  }
}
