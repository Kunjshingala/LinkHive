import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/auth_error_handler.dart';
import '../../core/utils/locator.dart';
import '../../sharedWidgets/common_app_bar.dart';
import '../../sharedWidgets/custom_button.dart';
import '../../sharedWidgets/custom_text_field.dart';
import 'bloc/auth_bloc.dart';
import 'bloc/auth_event.dart';
import 'bloc/auth_state.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AuthBloc(authService: locator<AuthService>()),
      child: const _SignupScreenContent(),
    );
  }
}

class _SignupScreenContent extends StatefulWidget {
  const _SignupScreenContent();

  @override
  State<_SignupScreenContent> createState() => _SignupScreenContentState();
}

class _SignupScreenContentState extends State<_SignupScreenContent> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _signUp(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.signupPasswordMismatch), backgroundColor: AppColors.error));
        return;
      }

      context.read<AuthBloc>().add(
        AuthSignUpRequested(email: _emailController.text.trim(), password: _passwordController.text.trim()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthError) {
          String errorMessage = state.message;
          if (state.exception is FirebaseAuthException) {
            errorMessage = AuthErrorHandler.getMessage(context, state.exception as FirebaseAuthException);
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error));
        } else if (state is AuthSuccess) {
          // On success, pop back to AuthGate which will show home
          while (context.canPop()) {
            context.pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.brandBackground,
        appBar: const CommonAppBar(backgroundColor: Colors.transparent),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.signupTitle,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.l10n.signupDesc,
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
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: _confirmPasswordController,
                    hintText: context.l10n.signupConfirmPasswordHint,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline,
                    validator: (value) =>
                        value != null && value.isNotEmpty ? null : context.l10n.signupConfirmPasswordError,
                  ),
                  const SizedBox(height: 24),
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoading;
                      return NeoBrutalistButton(
                        onPressed: () => _signUp(context),
                        text: context.l10n.signupButton,
                        isLoading: isLoading,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      );
                    },
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
