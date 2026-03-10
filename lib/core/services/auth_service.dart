import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _isInitialized = false;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Current user
  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _googleSignIn.initialize();
      _isInitialized = true;
    }
  }

  // Sign in with Email and Password
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    return await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Sign up with Email and Password
  Future<UserCredential?> signUpWithEmailPassword(String email, String password) async {
    return await _firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureInitialized();

    // Trigger the authentication flow
    final googleUser = await _googleSignIn.authenticate();

    // Obtain the authentication detail (idToken)
    final googleAuth = googleUser.authentication;

    // Obtain the authorization detail (accessToken)
    final authorization = await googleUser.authorizationClient.authorizeScopes([]);

    // Create a new credential
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: authorization.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase with the Google [UserCredential]
    return await _firebaseAuth.signInWithCredential(credential);
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore signOut errors if not signed in with Google
    }
    await _firebaseAuth.signOut();
  }
}
