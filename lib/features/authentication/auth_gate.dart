import 'package:flutter/material.dart';

import '../home/home.dart';

/// Phase 1: Local-First Auth Gate.
///
/// The app no longer gates unauthenticated users to a login screen.
/// HomeScreen is always shown. The optional sign-in flow is initiated
/// from the Account screen or the LocalModeBanner inside HomeScreen.
///
/// HomeScreen itself reads FirebaseAuth.currentUser to decide whether
/// to show the LocalModeBanner (guest mode indicator).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Always go to HomeScreen. Auth is opt-in via Account screen.
    return const HomeScreen();
  }
}
