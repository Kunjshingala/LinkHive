import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/link_metadata_service.dart';
import 'package:link_hive/core/services/metadata/metadata_fetcher.dart';

class _FakeMetadataFetcher implements MetadataFetcher {
  _FakeMetadataFetcher(this.html);

  final String? html;

  @override
  Future<String?> fetchHtml(Uri uri) async => html;
}

void main() {
  group('LinkMetadata', () {
    test('default constructor has empty fields', () {
      const metadata = LinkMetadata();
      expect(metadata.title, '');
      expect(metadata.image, '');
      expect(metadata.description, '');
    });

    test('constructor assigns all fields', () {
      const metadata = LinkMetadata(
        title: 'Test',
        image: 'https://img.png',
        description: 'Desc',
      );
      expect(metadata.title, 'Test');
      expect(metadata.image, 'https://img.png');
      expect(metadata.description, 'Desc');
    });
  });

  group('LinkMetadataService', () {
    late LinkMetadataService service;

    setUp(() {
      service = LinkMetadataService();
    });

    test('never throws — returns empty LinkMetadata on invalid URL', () async {
      final result = await service.fetchMetadata('not-a-valid-url');
      expect(result, isA<LinkMetadata>());
      expect(result.title, isEmpty);
    });

    test('never throws — returns empty LinkMetadata on empty string', () async {
      final result = await service.fetchMetadata('');
      expect(result, isA<LinkMetadata>());
    });

    test(
      'never throws — returns empty LinkMetadata on unreachable host',
      () async {
        final result = await service.fetchMetadata(
          'https://this-domain-does-not-exist-12345.com',
        );
        expect(result, isA<LinkMetadata>());
        expect(result.title, isEmpty);
      },
    );

    test('parses metadata from the platform fetcher', () async {
      service = LinkMetadataService(
        fetcher: _FakeMetadataFetcher('''
          <html><head>
            <meta property="og:title" content="Example title">
            <meta name="og:description" content="Example description">
            <link rel="icon" href="/favicon.png">
          </head></html>
        '''),
      );

      final result = await service.fetchMetadata('https://example.com/article');

      expect(result.title, 'Example title');
      expect(result.description, 'Example description');
      expect(result.image, 'https://example.com/favicon.png');
    });

    test(
      'unwraps double-escaped numeric entities (LinkedIn og:description)',
      () async {
        service = LinkMetadataService(
          fetcher: _FakeMetadataFetcher('''
          <meta property="og:title" content="Kunj Shingala - White Label Fox Pvt. Ltd. | LinkedIn">
          <meta property="og:description" content="I build mobile apps - mostly in Flutter, native when Flutter can&amp;#39;t get the job done">
        '''),
        );

        final result = await service.fetchMetadata(
          'https://in.linkedin.com/in/kunjshingala09',
        );

        expect(
          result.description,
          "I build mobile apps - mostly in Flutter, native when Flutter can't get the job done",
        );
      },
    );

    test(
      'still keeps an escaped named entity literal ("&amp;lt;" → "&lt;")',
      () async {
        service = LinkMetadataService(
          fetcher: _FakeMetadataFetcher(
            '<meta property="og:title" content="Use &amp;lt;div&amp;gt; tags">',
          ),
        );

        final result = await service.fetchMetadata('https://example.com/a');

        expect(result.title, 'Use &lt;div&gt; tags');
      },
    );

    test(
      'a refused request (no HTML) leaves the title empty so it can be fetched later',
      () async {
        service = LinkMetadataService(fetcher: _FakeMetadataFetcher(null));

        final result = await service.fetchMetadata(
          'https://www.linkedin.com/in/kunjshingala09',
        );

        expect(result.title, isEmpty);
      },
    );
  });
}
