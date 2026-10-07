import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/features/links/manager/link_manager.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

void main() {
  // LinkManager calls showSnackBar on failure, which reads
  // scaffoldMessengerKey.currentState and therefore WidgetsBinding.instance.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLinkRepository repository;
  late MockUrlLauncher launcher;
  late LinkManager manager;

  final link = LinkModel(
    id: '1',
    url: 'https://wellfound.com/jobs',
    title: 'Jobs',
    createdAt: 1000,
  );

  setUpAll(() {
    registerFallbackValue(const LaunchOptions());
  });

  setUp(() {
    repository = MockLinkRepository();
    launcher = MockUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    manager = LinkManager(repository: repository);

    when(() => launcher.launchUrl(any(), any())).thenAnswer((_) async => true);
    when(() => repository.markLinkAsRead(any())).thenAnswer((_) async {});
    when(() => repository.markResurfaced(any())).thenAnswer((_) async {});
  });

  group('openLink', () {
    test('records the link as consumed and launches it', () async {
      await manager.openLink(link);

      verify(() => repository.markLinkAsRead('1')).called(1);
      verify(() => repository.markResurfaced('1')).called(1);
      verify(() => launcher.launchUrl(link.url, any())).called(1);
    });

    test('opens a picked version instead of the main URL', () async {
      const version = 'https://flutter.dev/?utm_source=youtube&cid=affiliate';

      await manager.openLink(link, url: version);

      verify(() => repository.markLinkAsRead('1')).called(1);
      verify(() => launcher.launchUrl(version, any())).called(1);
      verifyNever(() => launcher.launchUrl(link.url, any()));
    });

    test(
      'records BEFORE launching, so a killed process cannot lose it',
      () async {
        await manager.openLink(link);

        // The ordering is the whole point: on a cold start the browser
        // backgrounds the app immediately and the continuation after the launch
        // is not guaranteed to run.
        verifyInOrder([
          () => repository.markLinkAsRead('1'),
          () => repository.markResurfaced('1'),
          () => launcher.launchUrl(link.url, any()),
        ]);
      },
    );

    test('uses the in-app browser for https', () async {
      await manager.openLink(link);

      final options =
          verify(
                () => launcher.launchUrl(link.url, captureAny()),
              ).captured.single
              as LaunchOptions;
      expect(options.mode, PreferredLaunchMode.inAppBrowserView);
    });

    test('uses the external app for a non-http(s) scheme', () async {
      // inAppBrowserView throws ArgumentError on these; regression guard for
      // the bug fixed in 7e60443.
      final mailto = LinkModel(
        id: '2',
        url: 'mailto:someone@example.com',
        title: 'Mail',
        createdAt: 2000,
      );

      await manager.openLink(mailto);

      final options =
          verify(
                () => launcher.launchUrl(mailto.url, captureAny()),
              ).captured.single
              as LaunchOptions;
      expect(options.mode, PreferredLaunchMode.externalApplication);
    });

    test('still records the link when the launch returns false', () async {
      when(
        () => launcher.launchUrl(any(), any()),
      ).thenAnswer((_) async => false);

      await manager.openLink(link);

      verify(() => repository.markLinkAsRead('1')).called(1);
      verify(() => repository.markResurfaced('1')).called(1);
    });

    test('still records the link when the launch throws', () async {
      when(() => launcher.launchUrl(any(), any())).thenThrow(Exception('boom'));

      await manager.openLink(link);

      verify(() => repository.markLinkAsRead('1')).called(1);
      verify(() => repository.markResurfaced('1')).called(1);
    });

    test('does not record or launch when the url cannot be parsed', () async {
      final bad = LinkModel(
        id: '3',
        // A bare colon is not a parseable URI.
        url: '::::',
        title: 'Broken',
        createdAt: 3000,
      );

      await manager.openLink(bad);

      verifyNever(() => repository.markLinkAsRead(any()));
      verifyNever(() => launcher.launchUrl(any(), any()));
    });

    test(
      'swallows a repository failure instead of throwing at the caller',
      () async {
        // Callers are fire-and-forget (the widget path runs unawaited), so an
        // exception here would vanish and look like a tap that did nothing.
        when(
          () => repository.markLinkAsRead(any()),
        ).thenThrow(Exception('hive down'));

        await expectLater(manager.openLink(link), completes);
      },
    );
  });

  group('archiveLink', () {
    test('records the link as consumed without launching anything', () async {
      await manager.archiveLink(link);

      verify(() => repository.markLinkAsRead('1')).called(1);
      verify(() => repository.markResurfaced('1')).called(1);
      verifyNever(() => launcher.launchUrl(any(), any()));
    });
  });

  group('snoozeLink', () {
    test('records it was shown but leaves it unread', () async {
      await manager.snoozeLink(link);

      verify(() => repository.markResurfaced('1')).called(1);
      // The whole point of snooze: it must come back later.
      verifyNever(() => repository.markLinkAsRead(any()));
      verifyNever(() => launcher.launchUrl(any(), any()));
    });
  });

  group('currentPick', () {
    test('returns the repository candidate', () {
      when(() => repository.getResurfaceCandidate()).thenReturn(link);
      expect(manager.currentPick(), link);
    });

    test('returns null when nothing is left to resurface', () {
      when(() => repository.getResurfaceCandidate()).thenReturn(null);
      expect(manager.currentPick(), isNull);
    });
  });
}
