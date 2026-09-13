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

    test('never throws — returns empty LinkMetadata on unreachable host', () async {
      final result = await service.fetchMetadata(
        'https://this-domain-does-not-exist-12345.com',
      );
      expect(result, isA<LinkMetadata>());
      expect(result.title, isEmpty);
    });

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
  });
}
