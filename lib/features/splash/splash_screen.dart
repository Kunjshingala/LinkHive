import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/context_extension.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/navigation/route.dart';
import '../../sharedWidgets/app_logo.dart';
import '../../sharedWidgets/common_app_bar.dart';
import 'bloc/splash_bloc.dart';
import 'bloc/splash_event.dart';
import 'bloc/splash_state.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SplashBloc()..add(const SplashStarted()),
      child: const _SplashScreenContent(),
    );
  }
}

class _SplashScreenContent extends StatelessWidget {
  const _SplashScreenContent();

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashBloc, SplashState>(
      listener: (context, state) {
        if (state is SplashComplete) {
          if (context.mounted) {
            context.pushReplacementNamed(MyRouteName.homeScreen);
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.brandBackground,
        appBar: const CommonAppBar(toolbarHeight: 0),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(size: 100),
              const SizedBox(height: AppSpacing.lg),
              Text(context.l10n.appTitle, style: Theme.of(context).textTheme.displayLarge),
            ],
          ),
        ),
      ),
    );
  }
}
