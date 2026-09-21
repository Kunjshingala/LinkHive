import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../extensions/context_extension.dart';

class AuthErrorHandler {
  static String getMessage(BuildContext context, FirebaseAuthException e) {
    switch (e.code) {
      // Firebase's Email Enumeration Protection (on by default) reports both a
      // missing account and a bad password as 'invalid-credential', so the two
      // cases below only fire on projects where that protection is disabled.
      case 'invalid-credential':
        return context.l10n.authErrInvalidCredential;
      case 'user-not-found':
        return context.l10n.authErrUserNotFound;
      case 'wrong-password':
        return context.l10n.authErrWrongPassword;
      case 'email-already-in-use':
        return context.l10n.authErrEmailAlreadyInUse;
      case 'weak-password':
        return context.l10n.authErrWeakPassword;
      case 'invalid-email':
        return context.l10n.authErrInvalidEmail;
      default:
        // Use the generated function to format the error message with the dynamic value
        return context.l10n.authErrDefault(e.message ?? e.code);
    }
  }
}
