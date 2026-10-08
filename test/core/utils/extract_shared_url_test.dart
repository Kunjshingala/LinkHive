import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/utils/validator/validator.dart';

/// Real share texts from shopping apps: the link comes after a sentence.
void main() {
  group('extractSharedUrl', () {
    test('a bare link is returned as is', () {
      expect(
        extractSharedUrl('https://youtu.be/Px_3O3KeR24?si=abc'),
        'https://youtu.be/Px_3O3KeR24?si=abc',
      );
    });

    test('Flipkart: sentence, newline, link', () {
      expect(
        extractSharedUrl(
          'Take a look at this Men Outdoor Comfortable Lightweight Everyday Use Casual Sandal on Flipkart\nhttps://dl.flipkart.com/s/oOn2ecuuuN',
        ),
        'https://dl.flipkart.com/s/oOn2ecuuuN',
      );
    });

    test('Amazon: "Deal:" title then the link on the same line', () {
      expect(
        extractSharedUrl(
          'Deal: Visio World VW 80 cm (32 inches) Smartchoice Spectra Series HD Ready Smart QLED Android TV VW32AQ3 https://amzn.in/d/0fIAxpn6',
        ),
        'https://amzn.in/d/0fIAxpn6',
      );
    });

    test('takes the first link and drops sentence punctuation', () {
      expect(
        extractSharedUrl(
          'See https://example.com/a, or https://example.com/b.',
        ),
        'https://example.com/a',
      );
      expect(
        extractSharedUrl('(https://example.com/page)'),
        'https://example.com/page',
      );
      expect(
        extractSharedUrl('Read this: https://example.com/page.'),
        'https://example.com/page',
      );
    });

    test('keeps query strings and fragments', () {
      expect(
        extractSharedUrl('Look https://shop.example/p?a=1&b=2#/item/1 now'),
        'https://shop.example/p?a=1&b=2#/item/1',
      );
    });

    test('other apps: Myntra, an uppercase scheme, text after the link', () {
      expect(
        extractSharedUrl(
          'Check out this kurta on Myntra: HTTPS://www.myntra.com/12345?utm_source=share thanks!',
        ),
        'HTTPS://www.myntra.com/12345?utm_source=share',
      );
    });

    test('a link in angle brackets or quotes loses the wrapper', () {
      expect(
        extractSharedUrl('Link <https://example.com/page> here'),
        'https://example.com/page',
      );
      expect(
        extractSharedUrl('"https://example.com/page"'),
        'https://example.com/page',
      );
    });

    test('text without a link gives null', () {
      expect(extractSharedUrl('just some words'), isNull);
      expect(extractSharedUrl('ftp://example.com/file'), isNull);
      expect(extractSharedUrl('http://localhost/x'), isNull);
      expect(extractSharedUrl(''), isNull);
    });
  });
}
