import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/app_enums.dart';
import '../../core/extensions/context_extension.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/auth_error_handler.dart';
import '../../core/utils/locator.dart';
import '../../core/utils/navigation/route.dart';
import '../../core/utils/utils.dart';
import '../../sharedWidgets/common_app_bar.dart';
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
            printLog(tag: 'Auth', msg: 'FirebaseAuthException: ${state.exception}');
          } else if (state.exception is GoogleSignInException) {
            final gex = state.exception as GoogleSignInException;
            printLog(tag: 'Auth', msg: 'GoogleSignInException: code=${gex.code} details=${gex.details}');
            showSnackBar('Google sign-in is unavailable right now. Please use email login.');
          } else {
            printLog(tag: 'Auth', msg: 'AuthError: ${state.message}');
            showSnackBar(context.l10n.authErrDefault(state.message));
          }
        } else if (state is AuthSuccess) {
          context.goNamed(MyRouteName.homeScreen);
        }
        // Navigation is handled via named routes.
      },
      child: Scaffold(
        backgroundColor: AppColors.brandBackground,
        appBar: const CommonAppBar(backgroundColor: AppColors.transparent),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    context.l10n.authWelcome,
                    style: context.text.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.l10n.authSignInDesc,
                    style: context.text.bodyLarge?.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  CustomTextField(
                    controller: _emailController,
                    hintText: context.l10n.authEmailHint,
                    prefixIcon: Icons.email_outlined,
                    validator: (value) => value != null && value.isNotEmpty ? null : context.l10n.authEmailError,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CustomTextField(
                    controller: _passwordController,
                    hintText: context.l10n.authPasswordHint,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) => value != null && value.length >= 6 ? null : context.l10n.authPasswordError,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final cs = context.colors;
                      final isLoading = state is AuthLoading;
                      return NeoBrutalistButton(
                        onPressed: () => _signIn(context),
                        text: context.l10n.authSignInButton,
                        isLoading: isLoading,
                        backgroundColor: cs.surface,
                        textColor: cs.onSurface,
                        shadowColor: cs.primary,
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  NeoBrutalistButton(
                    onPressed: () => _signInWithGoogle(context),
                    text: context.l10n.authGoogleSignIn,
                    icon: FontAwesomeIcons.google,
                    variant: ButtonVariant.outlined,
                    backgroundColor: context.colors.surface,
                    textColor: context.colors.onSurface,
                    shadowColor: context.colors.primary,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(context.l10n.authNoAccount, style: context.text.bodyMedium),
                      TextButton(
                        onPressed: () {
                          context.pushNamed(MyRouteName.signup);
                        },
                        child: Text(
                          context.l10n.authSignUpLink,
                          style: context.text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.colors.primary,
                          ),
                        ),
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
