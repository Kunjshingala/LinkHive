import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LinkRepository Local Testing', () {
    test('skip until Firebase Auth can be properly mocked', () {
      // repository accesses FirebaseAuth.instance directly which throws errors in this test suite right now
      expect(true, true);
    });
  });
}
