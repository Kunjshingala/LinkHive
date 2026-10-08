import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/features/links/manager/link_manager.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:link_hive/features/today/bloc/today_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

/// `launchUrl` is a top-level function, so the only seam is the platform
/// instance underneath it. Swapping this still runs url_launcher's own
/// argument validation, which is where the non-http(s) bug lived.
class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

/// Regression coverage locking TodayBloc's behavior BEFORE the LinkManager
/// refactor moves these calls. Every assertion here describes behavior that
/// must survive the move:
///
/// - Open marks the link read AND resurfaced, then advances to the next pick.
/// - Archive does the same two writes without launching anything.
/// - Snooze records it was shown but leaves it unread, so it comes back later.
void main() {
  // TodayBloc calls showSnackBar on a failed launch, which reads
  // scaffoldMessengerKey.currentState and therefore WidgetsBinding.instance.
  // Business logic reaching into the widget tree is why this is needed at all;
  // LinkManager inherits the same constraint.
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLinkRepository repository;
  late MockUrlLauncher launcher;

  final first = LinkModel(
    id: '1',
    url: 'https://wellfound.com/jobs',
    title: 'Jobs',
    createdAt: 1000,
  );
  final second = LinkModel(
    id: '2',
    url: 'https://dart.dev',
    title: 'Dart',
    createdAt: 2000,
  );

  /// Returns each candidate in turn, then sticks on the last one.
  /// mocktail has no `thenReturnInOrder`, and the bloc re-queries the
  /// repository after every action, so the sequence is what "advances to the
  /// next pick" actually means.
  void stubCandidates(List<LinkModel?> sequence) {
    var index = 0;
    when(() => repository.getResurfaceCandidate()).thenAnswer(
      (_) => index < sequence.length ? sequence[index++] : sequence.last,
    );
  }

  setUpAll(() {
    registerFallbackValue(const LaunchOptions());
    registerFallbackValue(LinkModel(id: "", url: "", title: "", createdAt: 0));
  });

  setUp(() {
    repository = MockLinkRepository();
    launcher = MockUrlLauncher();
    UrlLauncherPlatform.instance = launcher;

    when(() => launcher.launchUrl(any(), any())).thenAnswer((_) async => true);
    when(() => repository.markLinkAsRead(any())).thenAnswer((_) async {});
    when(() => repository.markResurfaced(any())).thenAnswer((_) async {});
  });

  group('TodayBloc load', () {
    blocTest<TodayBloc, TodayState>(
      'emits Loading then Loaded with the current candidate',
      build: () {
        when(() => repository.getResurfaceCandidate()).thenReturn(first);
        return TodayBloc(manager: LinkManager(repository: repository));
      },
      act: (bloc) => bloc.add(const TodayLoadRequested()),
      expect: () => [const TodayLoading(), TodayLoaded(first)],
    );

    blocTest<TodayBloc, TodayState>(
      'emits Loading then Empty when nothing is left to resurface',
      build: () {
        when(() => repository.getResurfaceCandidate()).thenReturn(null);
        return TodayBloc(manager: LinkManager(repository: repository));
      },
      act: (bloc) => bloc.add(const TodayLoadRequested()),
      expect: () => [const TodayLoading(), const TodayEmpty()],
    );
  });

  group('TodayBloc open', () {
    blocTest<TodayBloc, TodayState>(
      'marks read and resurfaced, then advances to the next candidate',
      build: () {
        stubCandidates([first, second]);
        return TodayBloc(manager: LinkManager(repository: repository));
      },
      act: (bloc) async {
        bloc.add(const TodayLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TodayOpenRequested());
      },
      expect: () => [
        const TodayLoading(),
        TodayLoaded(first),
        TodayLoaded(second),
      ],
      verify: (_) {
        verify(() => repository.markLinkAsRead('1')).called(1);
        verify(() => repository.markResurfaced('1')).called(1);
        verify(() => launcher.launchUrl(first.url, any())).called(1);
      },
    );

    blocTest<TodayBloc, TodayState>(
      'still records the link when the launch fails',
      build: () {
        when(
          () => launcher.launchUrl(any(), any()),
        ).thenAnswer((_) async => false);
        stubCandidates([first, second]);
        return TodayBloc(manager: LinkManager(repository: repository));
      },
      act: (bloc) async {
        bloc.add(const TodayLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TodayOpenRequested());
      },
      verify: (_) {
        verify(() => repository.markLinkAsRead('1')).called(1);
        verify(() => repository.markResurfaced('1')).called(1);
      },
    );

    blocTest<TodayBloc, TodayState>(
      'does nothing when no candidate is loaded',
      build: () => TodayBloc(manager: LinkManager(repository: repository)),
      act: (bloc) => bloc.add(const TodayOpenRequested()),
      expect: () => const <TodayState>[],
      verify: (_) {
        verifyNever(() => repository.markLinkAsRead(any()));
        verifyNever(() => launcher.launchUrl(any(), any()));
      },
    );

    const affiliate =
        'https://wellfound.com/jobs?utm_source=youtube&ref=creator';

    blocTest<TodayBloc, TodayState>(
      'opens the version picked in the sheet',
      build: () {
        stubCandidates([first, second]);
        return TodayBloc(manager: LinkManager(repository: repository));
      },
      act: (bloc) async {
        bloc.add(const TodayLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TodayOpenRequested(url: affiliate));
      },
      skip: 2,
      expect: () => [TodayLoaded(second)],
      verify: (_) {
        verify(() => launcher.launchUrl(affiliate, any())).called(1);
        verify(() => repository.markLinkAsRead('1')).called(1);
        verifyNever(() => repository.updateLink(any()));
      },
    );

    blocTest<TodayBloc, TodayState>(
      '"Keep only this one" makes the pick the only URL, then opens it',
      setUp: () {
        when(
          () => repository.getLinkById('1'),
        ).thenReturn(first.copyWith(otherUrls: [affiliate]));
        when(() => repository.updateLink(any())).thenAnswer((_) async {});
      },
      build: () {
        stubCandidates([first, second]);
        return TodayBloc(manager: LinkManager(repository: repository));
      },
      act: (bloc) async {
        bloc.add(const TodayLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TodayOpenRequested(url: affiliate, keepOnly: true));
      },
      skip: 2,
      expect: () => [TodayLoaded(second)],
      verify: (_) {
        final kept =
            verify(() => repository.updateLink(captureAny())).captured.single
                as LinkModel;
        expect(kept.url, affiliate);
        expect(kept.otherUrls, isEmpty);
        verify(() => launcher.launchUrl(affiliate, any())).called(1);
      },
    );
  });

  group('TodayBloc archive', () {
    blocTest<TodayBloc, TodayState>(
      'marks read and resurfaced without launching anything',
      build: () {
        stubCandidates([first, second]);
        return TodayBloc(manager: LinkManager(repository: repository));
      },
      act: (bloc) async {
        bloc.add(const TodayLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TodayArchiveRequested());
      },
      expect: () => [
        const TodayLoading(),
        TodayLoaded(first),
        TodayLoaded(second),
      ],
      verify: (_) {
        verify(() => repository.markLinkAsRead('1')).called(1);
        verify(() => repository.markResurfaced('1')).called(1);
        verifyNever(() => launcher.launchUrl(any(), any()));
      },
    );
  });

  group('TodayBloc snooze', () {
    blocTest<TodayBloc, TodayState>(
      'records it was shown but leaves it unread so it comes back later',
      build: () {
        stubCandidates([first, second]);
        return TodayBloc(manager: LinkManager(repository: repository));
      },
      act: (bloc) async {
        bloc.add(const TodayLoadRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const TodaySnoozeRequested());
      },
      expect: () => [
        const TodayLoading(),
        TodayLoaded(first),
        TodayLoaded(second),
      ],
      verify: (_) {
        verify(() => repository.markResurfaced('1')).called(1);
        // The whole point of snooze: NOT read.
        verifyNever(() => repository.markLinkAsRead(any()));
      },
    );
  });
}
