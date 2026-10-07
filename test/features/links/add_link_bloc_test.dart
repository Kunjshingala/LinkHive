import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/link_metadata_service.dart';
import 'package:link_hive/features/links/bloc/add_link_bloc.dart';
import 'package:link_hive/features/links/bloc/add_link_event.dart';
import 'package:link_hive/features/links/bloc/add_link_state.dart';
import 'package:link_hive/features/links/manager/link_manager.dart';
import 'package:link_hive/features/links/models/link_model.dart';
import 'package:link_hive/features/links/repository/link_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockLinkRepository extends Mock implements LinkRepository {}

class MockLinkMetadataService extends Mock implements LinkMetadataService {}

void main() {
  group('AddLinkBloc', () {
    late MockLinkRepository mockRepository;
    late MockLinkMetadataService mockMetadataService;

    final testLink = LinkModel(
      id: 'test-id',
      url: 'https://flutter.dev',
      title: 'Flutter',
      description: 'Build apps',
      image: 'https://flutter.dev/image.png',
      categories: ['dev'],
      priority: 'High',
      createdAt: 123456789,
    );

    setUp(() {
      mockRepository = MockLinkRepository();
      mockMetadataService = MockLinkMetadataService();
      // Add mode saves through LinkManager.saveOrMerge, which first looks for
      // a saved duplicate. By default nothing matches, so add mode keeps
      // creating new links; the merge tests below override this.
      when(() => mockRepository.findByCanonicalUrl(any())).thenReturn(null);
    });

    setUpAll(() {
      registerFallbackValue(
        LinkModel(id: '', url: '', title: '', createdAt: 0),
      );
    });

    AddLinkBloc buildBloc() => AddLinkBloc(
      manager: LinkManager(repository: mockRepository),
      metadataService: mockMetadataService,
    );

    test('initial state is AddLinkInitial', () {
      final bloc = buildBloc();
      expect(bloc.state, const AddLinkInitial());
      bloc.close();
    });

    // ─── Initialization ──────────────────────────────────────────────

    group('AddLinkInitialized', () {
      blocTest<AddLinkBloc, AddLinkState>(
        'emits blank AddLinkForm when no prefillUrl or existingLink',
        build: buildBloc,
        act: (bloc) => bloc.add(const AddLinkInitialized()),
        expect: () => [const AddLinkForm()],
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'emits pre-filled AddLinkForm in edit mode',
        build: buildBloc,
        act: (bloc) => bloc.add(AddLinkInitialized(existingLink: testLink)),
        expect: () => [
          AddLinkForm(
            url: testLink.url,
            title: testLink.title,
            description: testLink.description,
            image: testLink.image,
            priority: testLink.priority,
            categories: testLink.categories,
          ),
        ],
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'emits AddLinkForm with prefillUrl and triggers metadata fetch',
        build: () {
          when(
            () => mockMetadataService.fetchMetadata('https://flutter.dev'),
          ).thenAnswer(
            (_) async => const LinkMetadata(
              title: 'Flutter',
              description: 'Build apps',
              image: 'https://flutter.dev/img.png',
            ),
          );
          return buildBloc();
        },
        act: (bloc) => bloc.add(
          const AddLinkInitialized(prefillUrl: 'https://flutter.dev'),
        ),
        expect: () => [
          // Form emitted from initialization
          const AddLinkForm(url: 'https://flutter.dev'),
          // Metadata fetch starts (isFetchingMetadata: true)
          const AddLinkForm(
            url: 'https://flutter.dev',
            isFetchingMetadata: true,
          ),
          // Metadata fetch completes
          const AddLinkForm(
            url: 'https://flutter.dev',
            title: 'Flutter',
            description: 'Build apps',
            image: 'https://flutter.dev/img.png',
            isFetchingMetadata: false,
          ),
        ],
      );
    });

    // ─── Metadata Fetch ──────────────────────────────────────────────

    group('AddLinkFetchMetadata', () {
      blocTest<AddLinkBloc, AddLinkState>(
        'populates empty fields with fetched metadata',
        build: () {
          when(
            () => mockMetadataService.fetchMetadata('https://example.com'),
          ).thenAnswer(
            (_) async => const LinkMetadata(
              title: 'Example',
              description: 'Example site',
              image: 'https://example.com/img.png',
            ),
          );
          return buildBloc();
        },
        seed: () => const AddLinkForm(url: 'https://example.com'),
        act: (bloc) =>
            bloc.add(const AddLinkFetchMetadata('https://example.com')),
        expect: () => [
          const AddLinkForm(
            url: 'https://example.com',
            isFetchingMetadata: true,
          ),
          const AddLinkForm(
            url: 'https://example.com',
            title: 'Example',
            description: 'Example site',
            image: 'https://example.com/img.png',
            isFetchingMetadata: false,
          ),
        ],
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'fetched metadata overwrites fields when metadata is non-empty',
        build: () {
          when(
            () => mockMetadataService.fetchMetadata('https://example.com'),
          ).thenAnswer(
            (_) async => const LinkMetadata(
              title: 'Fetched Title',
              description: 'Fetched Desc',
              image: 'https://example.com/fetched.png',
            ),
          );
          return buildBloc();
        },
        seed: () => const AddLinkForm(
          url: 'https://example.com',
          title: 'My Custom Title',
          description: 'My notes',
        ),
        act: (bloc) =>
            bloc.add(const AddLinkFetchMetadata('https://example.com')),
        expect: () => [
          const AddLinkForm(
            url: 'https://example.com',
            title: 'My Custom Title',
            description: 'My notes',
            isFetchingMetadata: true,
          ),
          // Fetched metadata overwrites because metadata values are non-empty
          const AddLinkForm(
            url: 'https://example.com',
            title: 'Fetched Title',
            description: 'Fetched Desc',
            image: 'https://example.com/fetched.png',
            isFetchingMetadata: false,
          ),
        ],
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'preserves user-typed content when fetched metadata is empty',
        build: () {
          when(
            () => mockMetadataService.fetchMetadata('https://example.com'),
          ).thenAnswer(
            (_) async => const LinkMetadata(
              title: '',
              description: '',
              image: 'https://example.com/fetched.png',
            ),
          );
          return buildBloc();
        },
        seed: () => const AddLinkForm(
          url: 'https://example.com',
          title: 'My Custom Title',
          description: 'My notes',
        ),
        act: (bloc) =>
            bloc.add(const AddLinkFetchMetadata('https://example.com')),
        expect: () => [
          const AddLinkForm(
            url: 'https://example.com',
            title: 'My Custom Title',
            description: 'My notes',
            isFetchingMetadata: true,
          ),
          // Title and description preserved; only image is populated
          const AddLinkForm(
            url: 'https://example.com',
            title: 'My Custom Title',
            description: 'My notes',
            image: 'https://example.com/fetched.png',
            isFetchingMetadata: false,
          ),
        ],
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'handles metadata fetch failure gracefully',
        build: () {
          when(
            () => mockMetadataService.fetchMetadata('https://bad-url.com'),
          ).thenAnswer((_) async => const LinkMetadata());
          return buildBloc();
        },
        seed: () => const AddLinkForm(url: 'https://bad-url.com'),
        act: (bloc) =>
            bloc.add(const AddLinkFetchMetadata('https://bad-url.com')),
        expect: () => [
          const AddLinkForm(
            url: 'https://bad-url.com',
            isFetchingMetadata: true,
          ),
          const AddLinkForm(
            url: 'https://bad-url.com',
            isFetchingMetadata: false,
          ),
        ],
      );

      late Completer<LinkMetadata> staleResult;
      blocTest<AddLinkBloc, AddLinkState>(
        'ignores stale metadata when the URL changes and fetches the new URL',
        build: () {
          staleResult = Completer<LinkMetadata>();
          when(
            () => mockMetadataService.fetchMetadata('https://old.example'),
          ).thenAnswer((_) => staleResult.future);
          when(
            () => mockMetadataService.fetchMetadata('https://new.example'),
          ).thenAnswer((_) async => const LinkMetadata(title: 'New page'));
          return buildBloc();
        },
        seed: () => const AddLinkForm(url: 'https://old.example'),
        act: (bloc) async {
          bloc.add(const AddLinkFetchMetadata('https://old.example'));
          await Future<void>.delayed(const Duration(milliseconds: 350));
          bloc.add(const AddLinkFieldChanged(url: 'https://new.example'));
          await Future<void>.delayed(const Duration(milliseconds: 350));
          staleResult.complete(const LinkMetadata(title: 'Old page'));
        },
        wait: const Duration(milliseconds: 300),
        expect: () => [
          const AddLinkForm(
            url: 'https://old.example',
            isFetchingMetadata: true,
          ),
          const AddLinkForm(url: 'https://new.example'),
          const AddLinkForm(
            url: 'https://new.example',
            isFetchingMetadata: true,
          ),
          const AddLinkForm(url: 'https://new.example', title: 'New page'),
        ],
      );
    });

    // ─── Field Changes ───────────────────────────────────────────────

    group('AddLinkFieldChanged', () {
      blocTest<AddLinkBloc, AddLinkState>(
        'updates only the changed field',
        build: buildBloc,
        seed: () => const AddLinkForm(url: 'https://flutter.dev'),
        act: (bloc) => bloc.add(const AddLinkFieldChanged(title: 'New Title')),
        expect: () => [
          const AddLinkForm(url: 'https://flutter.dev', title: 'New Title'),
        ],
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'updates priority and categories',
        build: buildBloc,
        seed: () => const AddLinkForm(url: 'https://flutter.dev'),
        act: (bloc) => bloc.add(
          const AddLinkFieldChanged(
            priority: 'High',
            categories: ['dev', 'flutter'],
          ),
        ),
        expect: () => [
          const AddLinkForm(
            url: 'https://flutter.dev',
            priority: 'High',
            categories: ['dev', 'flutter'],
          ),
        ],
      );
    });

    // ─── Save ────────────────────────────────────────────────────────

    group('AddLinkSaveRequested', () {
      blocTest<AddLinkBloc, AddLinkState>(
        'emits [AddLinkError, AddLinkForm] when URL is empty',
        build: buildBloc,
        seed: () => const AddLinkForm(url: '  ', title: 'No URL'),
        act: (bloc) => bloc.add(const AddLinkSaveRequested()),
        expect: () => [
          const AddLinkError('', code: AddLinkErrorCode.emptyUrl),
          const AddLinkForm(url: '  ', title: 'No URL'),
        ],
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'rejects a non-HTTP URL before saving',
        build: buildBloc,
        seed: () => const AddLinkForm(url: 'ftp://example.com'),
        act: (bloc) => bloc.add(const AddLinkSaveRequested()),
        expect: () => [
          const AddLinkError('', code: AddLinkErrorCode.invalidUrl),
          const AddLinkForm(url: 'ftp://example.com'),
        ],
        verify: (_) {
          verifyNever(() => mockRepository.addLink(any()));
        },
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'normalizes a scheme-less URL before saving',
        build: () {
          when(() => mockRepository.addLink(any())).thenAnswer((_) async {});
          return buildBloc();
        },
        seed: () => const AddLinkForm(url: 'flutter.dev'),
        act: (bloc) => bloc.add(const AddLinkSaveRequested()),
        expect: () => [const AddLinkSaving(), const AddLinkSuccess()],
        verify: (_) {
          final captured = verify(
            () => mockRepository.addLink(captureAny()),
          ).captured;
          final savedLink = captured.single as LinkModel;
          expect(savedLink.url, 'https://flutter.dev');
        },
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'emits [AddLinkSaving, AddLinkSuccess] on successful add',
        build: () {
          when(() => mockRepository.addLink(any())).thenAnswer((_) async {});
          return buildBloc();
        },
        seed: () =>
            const AddLinkForm(url: 'https://flutter.dev', title: 'Flutter'),
        act: (bloc) => bloc.add(const AddLinkSaveRequested()),
        expect: () => [const AddLinkSaving(), const AddLinkSuccess()],
        verify: (_) {
          verify(() => mockRepository.addLink(any())).called(1);
        },
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'calls updateLink in edit mode',
        build: () {
          when(() => mockRepository.updateLink(any())).thenAnswer((_) async {});
          return buildBloc();
        },
        act: (bloc) async {
          // First initialize in edit mode, then save
          bloc.add(AddLinkInitialized(existingLink: testLink));
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bloc.add(const AddLinkSaveRequested());
        },
        expect: () => [
          // From initialization
          AddLinkForm(
            url: testLink.url,
            title: testLink.title,
            description: testLink.description,
            image: testLink.image,
            priority: testLink.priority,
            categories: testLink.categories,
          ),
          // From save
          const AddLinkSaving(),
          const AddLinkSuccess(),
        ],
        verify: (_) {
          verify(() => mockRepository.updateLink(any())).called(1);
        },
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'emits [AddLinkSaving, AddLinkError] when repository throws',
        build: () {
          when(
            () => mockRepository.addLink(any()),
          ).thenThrow(Exception('DB error'));
          return buildBloc();
        },
        seed: () => const AddLinkForm(url: 'https://flutter.dev'),
        act: (bloc) => bloc.add(const AddLinkSaveRequested()),
        expect: () => [const AddLinkSaving(), isA<AddLinkError>()],
      );

      blocTest<AddLinkBloc, AddLinkState>(
        'uses URL as title when title is empty',
        build: () {
          when(() => mockRepository.addLink(any())).thenAnswer((_) async {});
          return buildBloc();
        },
        seed: () => const AddLinkForm(url: 'https://flutter.dev', title: ''),
        act: (bloc) => bloc.add(const AddLinkSaveRequested()),
        expect: () => [const AddLinkSaving(), const AddLinkSuccess()],
        verify: (_) {
          final captured = verify(
            () => mockRepository.addLink(captureAny()),
          ).captured;
          final savedLink = captured.first as LinkModel;
          expect(savedLink.title, 'https://flutter.dev');
        },
      );

      group('when the URL is already saved', () {
        void stubDuplicate() {
          when(
            () => mockRepository.findByCanonicalUrl(any()),
          ).thenReturn(testLink);
          when(() => mockRepository.updateLink(any())).thenAnswer((_) async {});
        }

        LinkModel savedUpdate() =>
            verify(
                  () => mockRepository.updateLink(captureAny()),
                ).captured.single
                as LinkModel;

        blocTest<AddLinkBloc, AddLinkState>(
          'merges instead of adding, keeping the curated title and priority',
          build: () {
            stubDuplicate();
            return buildBloc();
          },
          seed: () => const AddLinkForm(
            url: 'https://flutter.dev/?utm_source=newsletter',
            title: 'Some fetched title',
            priority: 'Normal',
            categories: ['news'],
          ),
          act: (bloc) => bloc.add(const AddLinkSaveRequested()),
          expect: () => [const AddLinkSaving(), isA<AddLinkMerged>()],
          verify: (_) {
            verifyNever(() => mockRepository.addLink(any()));
            final merged = savedUpdate();
            expect(merged.id, testLink.id);
            expect(merged.title, 'Flutter');
            expect(merged.priority, 'High');
            expect(merged.url, testLink.url);
            expect(merged.categories, unorderedEquals(['dev', 'news']));
            expect(merged.shareCount, 2);
          },
        );

        blocTest<AddLinkBloc, AddLinkState>(
          'a Tonight/Weekend pick sets the schedule on the merged link',
          build: () {
            stubDuplicate();
            return buildBloc();
          },
          seed: () => const AddLinkForm(
            url: 'https://flutter.dev',
            resurfaceAt: 1790000000000,
          ),
          act: (bloc) => bloc.add(const AddLinkSaveRequested()),
          expect: () => [const AddLinkSaving(), isA<AddLinkMerged>()],
          verify: (_) => expect(savedUpdate().resurfaceAt, 1790000000000),
        );

        blocTest<AddLinkBloc, AddLinkState>(
          'Someday brings it back unread without making it due',
          build: () {
            stubDuplicate();
            return buildBloc();
          },
          seed: () => const AddLinkForm(
            url: 'https://flutter.dev',
            clearResurfaceAt: true,
          ),
          act: (bloc) => bloc.add(const AddLinkSaveRequested()),
          expect: () => [const AddLinkSaving(), isA<AddLinkMerged>()],
          verify: (_) {
            final merged = savedUpdate();
            expect(merged.isRead, isFalse);
            expect(merged.resurfaceAt, isNull);
          },
        );
      });
    });
  });
}
