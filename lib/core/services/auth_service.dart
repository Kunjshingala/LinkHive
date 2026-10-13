import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../firebase_options.dart';
import '../utils/utils.dart';

class AuthService {
  /// The parameters replace the real Firebase and Google sources in tests.
  AuthService({FirebaseAuth? firebaseAuth, GoogleSignIn? googleSignIn})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  bool _isInitialized = false;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Current user
  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize(
        clientId: FirebaseConfig.iosClientId,
        serverClientId: FirebaseConfig.webClientId,
      );
      _isInitialized = true;
    }
  }

  // Sign in with Email and Password
  Future<UserCredential?> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with Email and Password
  Future<UserCredential?> signUpWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google.
  ///
  /// Returns `null` when the user dismisses the Google sheet — a cancel is a
  /// normal outcome, not a failure, so callers should stay where they are
  /// instead of surfacing an error.
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureInitialized();

    // Trigger the authentication flow
    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        printLog(tag: 'AuthService', msg: 'Google sign-in cancelled by user');
        return null;
      }
      rethrow;
    }

    // Obtain tokens
    final googleAuth = googleUser.authentication;

    // Create a new credential
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google [UserCredential]
    return await _firebaseAuth.signInWithCredential(credential);
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (error) {
      // Expected when the user did not sign in with Google. Not fatal: the
      // Firebase sign-out below ends the session either way. Logged so a real
      // Google failure leaves a trace.
      printLog(tag: 'AuthService', msg: 'Google sign-out failed: $error');
    }
    await _firebaseAuth.signOut();
  }
}
