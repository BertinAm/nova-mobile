import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/nova_design_system.dart';
import '../../../../core/tts/tts_service.dart';
import '../../../../injection_container.dart';
import '../bloc/auth_bloc.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<AuthBloc>(),
      child: const _AuthView(),
    );
  }
}

class _AuthView extends StatefulWidget {
  const _AuthView();

  @override
  State<_AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<_AuthView> {
  bool _isLogin = true;
  bool _obscurePassword = true;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<TtsService>().speak(
        'Welcome to NOVA. Please log in or create an account to get started.',
        priority: TtsPriority.normal,
      );
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _submit(BuildContext context) {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      getIt<TtsService>().speak(
        'Please fill in both your email and password.',
        priority: TtsPriority.high,
        interrupt: true,
      );
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (_isLogin) {
      context.read<AuthBloc>().add(AuthLoginRequested(email, pass));
    } else {
      context.read<AuthBloc>().add(AuthRegisterRequested(email, pass));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          getIt<TtsService>().speak(
            'You\'re all set! Taking you to the main menu.',
            priority: TtsPriority.high,
            interrupt: true,
          );
          Navigator.pushReplacementNamed(context, '/home');
        } else if (state is AuthError) {
          getIt<TtsService>().speak(
            state.message,
            priority: TtsPriority.high,
            interrupt: true,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: kNovaDanger,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (state is AuthRegisterSuccess) {
          getIt<TtsService>().speak(
            state.message,
            priority: TtsPriority.high,
            interrupt: true,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: kNovaSuccess,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() {
            _isLogin = true;
            _passCtrl.clear();
          });
        } else if (state is AuthLoading) {
          getIt<TtsService>().speak(
            _isLogin ? 'Logging you in, please wait.' : 'Creating your account, please wait.',
            priority: TtsPriority.normal,
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kPagePad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: kGapXL),

                  // ── Header ──────────────────────────────────────────────────
                  Semantics(
                    header: true,
                    child: Column(
                      children: [
                        // Logo glow circle
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kNovaPrimary.withValues(alpha: 0.12),
                            border: Border.all(color: kNovaPrimary, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: kNovaPrimary.withValues(alpha: 0.3),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.accessibility_new_rounded,
                              size: 44, color: kNovaPrimary),
                        ),
                        const SizedBox(height: kGapM),
                        Text(
                          _isLogin ? 'Welcome Back' : 'Create Account',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: kNovaOnSurface,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: kGapS),
                        Text(
                          _isLogin
                              ? 'Log in to sync your preferences and access all features.'
                              : 'Sign up to unlock scene description, cloud backup, and more.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kNovaSubtext, fontSize: 16),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: kGapXL),

                  // ── Email Field ──────────────────────────────────────────────
                  MergeSemantics(
                    child: Semantics(
                      label: 'Email address field',
                      textField: true,
                      child: TextField(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: true,
                        enabled: !isLoading,
                        onSubmitted: (_) => _passFocus.requestFocus(),
                        style: const TextStyle(color: kNovaOnSurface, fontSize: 18),
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.email_outlined, color: kNovaPrimary),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: kGapM),

                  // ── Password Field ───────────────────────────────────────────
                  MergeSemantics(
                    child: Semantics(
                      label: 'Password field',
                      textField: true,
                      child: TextField(
                        controller: _passCtrl,
                        focusNode: _passFocus,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !isLoading,
                        onSubmitted: (_) => _submit(context),
                        style: const TextStyle(color: kNovaOnSurface, fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: _isLogin ? '••••••••' : 'At least 8 characters',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: kNovaPrimary),
                          suffixIcon: Semantics(
                            button: true,
                            label: _obscurePassword ? 'Show password' : 'Hide password',
                            child: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                                color: kNovaSubtext,
                              ),
                              onPressed: isLoading
                                  ? null
                                  : () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: kGapXL),

                  // ── Primary Action ───────────────────────────────────────────
                  NovaBigButton(
                    label: _isLogin ? 'Log In' : 'Create Account',
                    icon: _isLogin ? Icons.login_rounded : Icons.person_add_rounded,
                    loading: isLoading,
                    enabled: !isLoading,
                    semanticHint: _isLogin
                        ? 'Double tap to log into your account'
                        : 'Double tap to create a new account',
                    onTap: () => _submit(context),
                  ),

                  const SizedBox(height: kGapM),

                  // ── Toggle Login/Register ─────────────────────────────────────
                  NovaOutlineButton(
                    label: _isLogin ? 'Don\'t have an account? Sign up' : 'Already have an account? Log in',
                    icon: Icons.swap_horiz_rounded,
                    enabled: !isLoading,
                    semanticHint: 'Switches between login and registration',
                    onTap: () {
                      setState(() => _isLogin = !_isLogin);
                      getIt<TtsService>().speak(
                        _isLogin
                            ? 'Switched to login. Enter your email and password.'
                            : 'Switched to registration. Enter an email and choose a password.',
                        priority: TtsPriority.normal,
                        interrupt: true,
                      );
                    },
                  ),

                  const SizedBox(height: kGapXL),

                  // ── Info note ─────────────────────────────────────────────────
                  const NovaInstructionCard(
                    message: 'Your data is encrypted and securely stored. '
                        'NOVA never shares your personal information.',
                    icon: Icons.shield_rounded,
                    semanticLabel: 'Privacy note: Your data is encrypted and securely stored.',
                  ),

                  const SizedBox(height: kGapXL),

                  // ── Demo Bypass ───────────────────────────────────────────────
                  NovaOutlineButton(
                    label: 'Continue Offline (Demo)',
                    icon: Icons.offline_bolt_rounded,
                    enabled: !isLoading,
                    borderColor: kNovaSecondary,
                    foregroundColor: kNovaSecondary,
                    semanticHint: 'Skips login and enters the app in offline mode for demonstration',
                    onTap: () {
                      getIt<TtsService>().speak(
                        'Entering offline demo mode.',
                        priority: TtsPriority.high,
                        interrupt: true,
                      );
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
