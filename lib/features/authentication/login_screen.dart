import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/auth_error_handler.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/utils.dart';
import '../../sharedWidgets/custom_button.dart';
import '../../sharedWidgets/custom_text_field.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';
import 'bloc/auth_state.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(authService: locator<AuthService>()),
      child: const _LoginScreenContent(),
    );
  }
}

class _LoginScreenContent extends StatefulWidget {
  const _LoginScreenContent();

  @override
  State<_LoginScreenContent> createState() => _LoginScreenContentState();
}

class _LoginScreenContentState extends State<_LoginScreenContent> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signIn(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(
        AuthSignInRequested(email: _emailController.text.trim(), password: _passwordController.text.trim()),
      );
    }
  }

  void _signInWithGoogle(BuildContext context) {
    context.read<AuthBloc>().add(const AuthGoogleSignInRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          if (state.exception is FirebaseAuthException) {
            showSnackBar(AuthErrorHandler.getMessage(context, state.exception as FirebaseAuthException));
          } else {
            showSnackBar(state.message);
          }
        }
        // Navigation is handled by AuthGate stream listener
      },
      child: Scaffold(
        backgroundColor: AppColors.brandBackground,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 50),
                  // Logo or Illustration could go here
                  Text(
                    context.l10n.authWelcome,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.l10n.authSignInDesc,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  CustomTextField(
                    controller: _emailController,
                    hintText: context.l10n.authEmailHint,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) => value != null && value.isNotEmpty ? null : context.l10n.authEmailError,
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: context.l10n.authPasswordHint,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) => value != null && value.length >= 6 ? null : context.l10n.authPasswordError,
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return NeoBrutalistButton(
                        onPressed: () => _signIn(context),
                        text: context.l10n.authSignInButton,
                        isLoading: isLoading,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: AppColors.border.withAlpha(50))),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                        child: Text(context.l10n.authOr, style: TextStyle(color: AppColors.textTertiary)),
                      ),
                      Expanded(child: Divider(color: AppColors.border.withAlpha(50))),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(height: AppSpacing.xl),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return OutlinedButton.icon(
                        onPressed: isLoading ? null : () => _signInWithGoogle(context),
                        icon: const Icon(FontAwesomeIcons.google, color: AppColors.error),
                        label: Text(
                          context.l10n.authGoogleSignIn,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(color: AppColors.border.withAlpha(50)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(context.l10n.authNoAccount, style: TextStyle(color: AppColors.textSecondary)),
                      TextButton(
                        onPressed: () {
                          context.push('/signup');
                        },
                        child: Text(context.l10n.authSignUpLink, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
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
