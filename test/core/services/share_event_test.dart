import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/services/share_event.dart';

/// Stands in for the plugin's SharedMediaFile: only `path` is read.
class _Item {
  const _Item(this.path);
  final String? path;
}

/// What a share-sheet event turns into: a link, "not a link", or "nothing".
void main() {
  group('shareEventUrl', () {
    test('Flipkart share: sentence, newline, link', () {
      final event = [
        const _Item(
          'Take a look at this Men Outdoor Comfortable Lightweight Everyday Use Casual Sandal on Flipkart\nhttps://dl.flipkart.com/s/oOn2ecuuuN',
        ),
      ];

      expect(shareEventUrl(event), 'https://dl.flipkart.com/s/oOn2ecuuuN');
    });

    test('Amazon share: "Deal:" title then the link', () {
      final event = [
        const _Item(
          'Deal: Visio World VW 80 cm (32 inches) Smartchoice Spectra Series HD Ready Smart QLED Android TV VW32AQ3 https://amzn.in/d/0fIAxpn6',
        ),
      ];

      expect(shareEventUrl(event), 'https://amzn.in/d/0fIAxpn6');
    });

    test('a bare link still works', () {
      expect(
        shareEventUrl([const _Item('https://youtu.be/Px_3O3KeR24?si=abc')]),
        'https://youtu.be/Px_3O3KeR24?si=abc',
      );
    });

    test('only the first shared item is read', () {
      final event = [
        const _Item('https://example.com/first'),
        const _Item('https://example.com/second'),
      ];

      expect(shareEventUrl(event), 'https://example.com/first');
    });

    test('text without a link, an empty list and null give null', () {
      expect(shareEventUrl([const _Item('just some words')]), isNull);
      expect(shareEventUrl([const _Item(null)]), isNull);
      expect(shareEventUrl(<_Item>[]), isNull);
      expect(shareEventUrl(null), isNull);
    });
  });

  group('shareEventHasContent', () {
    test('text that is not a link still counts as content', () {
      // This is what makes the "Only URL links can be saved" message show.
      expect(shareEventHasContent([const _Item('just some words')]), isTrue);
    });

    test('nothing shared is not content', () {
      expect(shareEventHasContent([const _Item(null)]), isFalse);
      expect(shareEventHasContent(<_Item>[]), isFalse);
      expect(shareEventHasContent(null), isFalse);
    });
  });
}
