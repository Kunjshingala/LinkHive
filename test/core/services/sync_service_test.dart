import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/sync_service.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

void main() {
  group('SyncService', () {
    late MockLinkRepository mockRepository;
    late SyncService syncService;

    setUp(() {
      mockRepository = MockLinkRepository();
      syncService = SyncService(linkRepository: mockRepository);
    });

    tearDown(() {
      syncService.dispose();
    });

    test('can be instantiated', () {
      expect(syncService, isNotNull);
    });

    test('dispose does not throw when called before startListening', () {
      expect(() => syncService.dispose(), returnsNormally);
    });

    // Note: startListening() creates InternetConnection() internally which
    // performs real network checks. Testing the full sync-on-connect flow
    // would require injecting the InternetConnection dependency.
    // The critical sync logic (syncPendingLinks) is covered via
    // LinkRepository and LinkBloc tests.
  });
}
