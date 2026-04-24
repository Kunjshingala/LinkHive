import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/link_metadata_service.dart';

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
  });
}
