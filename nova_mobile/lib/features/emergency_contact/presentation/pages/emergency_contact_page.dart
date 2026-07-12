import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/nova_design_system.dart';
import '../../../../core/tts/tts_service.dart';
import '../../../../injection_container.dart';
import '../bloc/emergency_contact_bloc.dart';

class EmergencyContactPage extends StatelessWidget {
  const EmergencyContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<EmergencyContactBloc>()..add(const LoadEmergencyContact()),
      child: const _EmergencyContactView(),
    );
  }
}

class _EmergencyContactView extends StatefulWidget {
  const _EmergencyContactView();

  @override
  State<_EmergencyContactView> createState() => _EmergencyContactViewState();
}

class _EmergencyContactViewState extends State<_EmergencyContactView> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  bool _hasUnsavedChanges = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_markDirty);
    _phoneCtrl.addListener(_markDirty);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<TtsService>().speak(
        'Emergency contact settings. '
        'This is the person who will be called when you say the word "emergency" from any screen.',
        priority: TtsPriority.normal,
      );
    });
  }

  void _markDirty() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_markDirty);
    _phoneCtrl.removeListener(_markDirty);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      getIt<TtsService>().speak(
        'Please enter the contact\'s name.',
        priority: TtsPriority.high,
        interrupt: true,
      );
      _nameFocus.requestFocus();
      return;
    }
    if (phone.isEmpty || phone.length < 7) {
      getIt<TtsService>().speak(
        'Please enter a valid phone number with at least 7 digits.',
        priority: TtsPriority.high,
        interrupt: true,
      );
      _phoneFocus.requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    getIt<TtsService>().speak(
      'Saving contact, please wait.',
      priority: TtsPriority.normal,
    );
    context.read<EmergencyContactBloc>().add(SetEmergencyContact(name, phone));
  }

  void _delete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Remove Contact?'),
        content: const Text(
          'This will delete your emergency contact. '
          'The emergency voice command will no longer be able to call anyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _nameCtrl.clear();
              _phoneCtrl.clear();
              context.read<EmergencyContactBloc>().add(const DeleteEmergencyContact());
              getIt<TtsService>().speak(
                'Deleting contact.',
                priority: TtsPriority.normal,
              );
            },
            child: Text('Delete', style: TextStyle(color: kNovaDanger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NovaScaffold(
      featureNumber: 7,
      title: 'Emergency Contact',
      icon: Icons.contact_emergency_rounded,
      semanticPageLabel: 'Emergency Contact settings',
      body: BlocConsumer<EmergencyContactBloc, EmergencyContactState>(
        listener: (context, state) {
          if (state is EmergencyContactError) {
            getIt<TtsService>().speak(
              'Something went wrong. ${state.message}',
              priority: TtsPriority.high,
              interrupt: true,
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: kNovaDanger,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is EmergencyContactLoaded) {
            setState(() => _hasUnsavedChanges = false);
            if (state.contact != null) {
              // Only update fields if they don't already match
              // (avoids cursor jumping when user just saved)
              if (_nameCtrl.text != state.contact!.contactName) {
                _nameCtrl.text = state.contact!.contactName;
              }
              if (_phoneCtrl.text != state.contact!.phoneNumber) {
                _phoneCtrl.text = state.contact!.phoneNumber;
              }
              getIt<TtsService>().speak(
                'Contact saved. ${state.contact!.contactName} is now your emergency contact.',
                priority: TtsPriority.high,
                interrupt: true,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${state.contact!.contactName} saved as your emergency contact.'),
                  backgroundColor: kNovaSuccess,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              getIt<TtsService>().speak(
                'Emergency contact removed. You can add a new one anytime.',
                priority: TtsPriority.normal,
              );
            }
          }
        },
        builder: (context, state) {
          final isLoading = state is EmergencyContactLoading;
          final contact = state is EmergencyContactLoaded ? state.contact : null;

          if (isLoading && _nameCtrl.text.isEmpty) {
            return const NovaLoadingState(
              message: 'Loading your emergency contact…',
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(kPagePad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const NovaInstructionCard(
                  message: 'This contact will be called when you say "Emergency" from any screen. '
                      'Make sure the phone number is correct and includes the country code if needed.',
                  icon: Icons.emergency_rounded,
                  semanticLabel: 'Instruction: This contact will be called when you say Emergency from any screen.',
                ),
                const SizedBox(height: kGapL),

                // ── Contact Name ──────────────────────────────────────────────
                MergeSemantics(
                  child: Semantics(
                    label: 'Contact Name',
                    textField: true,
                    child: TextField(
                      controller: _nameCtrl,
                      focusNode: _nameFocus,
                      textInputAction: TextInputAction.next,
                      enabled: !isLoading,
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _phoneFocus.requestFocus(),
                      decoration: const InputDecoration(
                        labelText: 'Contact Name',
                        hintText: 'e.g. Mom, Dad, Nurse Ambe',
                        prefixIcon: Icon(Icons.person, color: kNovaPrimary),
                      ),
                      style: const TextStyle(color: kNovaOnSurface, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: kGapM),

                // ── Phone Number ──────────────────────────────────────────────
                MergeSemantics(
                  child: Semantics(
                    label: 'Phone Number',
                    textField: true,
                    child: TextField(
                      controller: _phoneCtrl,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      enabled: !isLoading,
                      onSubmitted: (_) => _save(context),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g. +237 6XX XXX XXX',
                        prefixIcon: Icon(Icons.phone, color: kNovaPrimary),
                      ),
                      style: const TextStyle(color: kNovaOnSurface, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(height: kGapXL),

                // ── Save Button ───────────────────────────────────────────────
                NovaBigButton(
                  label: contact != null ? 'Update Contact' : 'Save Contact',
                  icon: Icons.save_rounded,
                  loading: isLoading,
                  enabled: !isLoading,
                  semanticHint: 'Double tap to save your emergency contact',
                  onTap: () => _save(context),
                ),

                // ── Delete Button ─────────────────────────────────────────────
                if (contact != null) ...[
                  const SizedBox(height: kGapM),
                  NovaOutlineButton(
                    label: 'Remove Emergency Contact',
                    icon: Icons.delete_outline_rounded,
                    enabled: !isLoading,
                    borderColor: kNovaDanger,
                    foregroundColor: kNovaDanger,
                    semanticHint: 'Double tap to remove your emergency contact',
                    onTap: () => _delete(context),
                  ),
                ],

                // ── Status info ───────────────────────────────────────────────
                if (contact != null) ...[
                  const SizedBox(height: kGapXL),
                  _ContactStatusCard(
                    name: contact.contactName,
                    phone: contact.phoneNumber,
                  ),
                ],

                const SizedBox(height: kGapM),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shows the currently saved contact in a nice card.
class _ContactStatusCard extends StatelessWidget {
  const _ContactStatusCard({required this.name, required this.phone});
  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Current emergency contact: $name, phone number: $phone',
      child: Container(
        padding: const EdgeInsets.all(kGapM),
        decoration: BoxDecoration(
          color: kNovaSuccess.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kNovaSuccess.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kNovaSuccess.withValues(alpha: 0.15),
                border: Border.all(color: kNovaSuccess.withValues(alpha: 0.4), width: 1.5),
              ),
              child: const Icon(Icons.check_circle_rounded, color: kNovaSuccess, size: 28),
            ),
            const SizedBox(width: kGapM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: kNovaOnSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: const TextStyle(color: kNovaSubtext, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active — say "Emergency" to call',
                    style: TextStyle(color: kNovaSuccess.withValues(alpha: 0.8), fontSize: 13),
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
