import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/nova_design_system.dart';
import '../../../../injection_container.dart';
import '../../home/presentation/pages/home_menu_page.dart';
import 'bloc/auth_bloc.dart';
import 'pages/auth_page.dart';

/// Root-level wrapper that checks whether a user is authenticated.
///
/// Shows a branded splash screen while the check is in progress, then
/// routes to either the [HomeMenuPage] or the [AuthPage].
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthBloc>()..add(const AuthCheckRequested()),
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state is AuthInitial || state is AuthLoading) {
            return const _NovaSplash();
          }
          if (state is AuthAuthenticated) {
            return const HomeMenuPage();
          }
          return const AuthPage();
        },
      ),
    );
  }
}

/// Branded splash screen shown while the auth check resolves.
class _NovaSplash extends StatelessWidget {
  const _NovaSplash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Glowing logo ────────────────────────────────────────────────
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kNovaPrimary.withValues(alpha: 0.12),
                border: Border.all(color: kNovaPrimary, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: kNovaPrimary.withValues(alpha: 0.35),
                    blurRadius: 30,
                    spreadRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.accessibility_new_rounded,
                  size: 48, color: kNovaPrimary),
            ),
            const SizedBox(height: kGapL),
            const Text(
              'NOVA',
              style: TextStyle(
                color: kNovaOnSurface,
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
              ),
            ),
            const SizedBox(height: kGapS),
            const Text(
              'Getting things ready…',
              style: TextStyle(color: kNovaSubtext, fontSize: 16),
            ),
            const SizedBox(height: kGapXL),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: kNovaPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
