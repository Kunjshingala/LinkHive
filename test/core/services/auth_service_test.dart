import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:link_hive/core/services/auth_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

void main() {
  late MockFirebaseAuth firebaseAuth;
  late MockGoogleSignIn googleSignIn;
  late AuthService service;

  setUp(() {
    firebaseAuth = MockFirebaseAuth();
    googleSignIn = MockGoogleSignIn();
    when(() => firebaseAuth.signOut()).thenAnswer((_) async {});
    when(() => googleSignIn.signOut()).thenAnswer((_) async {});
    service = AuthService(
      firebaseAuth: firebaseAuth,
      googleSignIn: googleSignIn,
    );
  });

  group('signOut', () {
    test('signs out of Google, then of Firebase', () async {
      await service.signOut();

      verifyInOrder([
        () => googleSignIn.signOut(),
        () => firebaseAuth.signOut(),
      ]);
    });

    test(
      'still ends the Firebase session when the Google sign-out fails',
      () async {
        when(
          () => googleSignIn.signOut(),
        ).thenThrow(StateError('not signed in'));

        await expectLater(service.signOut(), completes);

        verify(() => firebaseAuth.signOut()).called(1);
      },
    );

    test('reports a failed Firebase sign-out', () async {
      when(() => firebaseAuth.signOut()).thenThrow(StateError('auth down'));

      await expectLater(service.signOut(), throwsA(isA<StateError>()));
    });
  });
}
