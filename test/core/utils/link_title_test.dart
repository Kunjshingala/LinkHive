import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/utils/link_title.dart';

/// The label shown when a site refused the metadata request (LinkedIn answers
/// HTTP 999 to anything that isn't a known preview bot), so the card doesn't
/// fall back to a raw URL full of tracking params.
void main() {
  group('fallbackTitle', () {
    test('LinkedIn profile share link becomes "handle · host"', () {
      expect(
        fallbackTitle(
          'https://www.linkedin.com/in/kunjshingala09?utm_source=share_via&utm_content=profile&utm_medium=member_android',
        ),
        'kunjshingala09 · linkedin.com',
      );
    });

    test('prefers a slug segment over a trailing id', () {
      expect(
        fallbackTitle(
          'https://www.flipkart.com/apple-airpods-pro-3-bluetooth/p/itm4a09e10dfed93?pid=ACCHNFX2FDJQXSXZ',
        ),
        'apple airpods pro 3 bluetooth · flipkart.com',
      );
    });

    test('decodes percent-encoding and drops m. prefixes', () {
      expect(
        fallbackTitle('https://m.example.com/blog/hello%20world_post'),
        'hello world post · example.com',
      );
    });

    test('a bare host shows just the host', () {
      expect(fallbackTitle('https://whitelabelfox.com/'), 'whitelabelfox.com');
    });

    test('an unparseable or host-less string is returned as-is', () {
      expect(fallbackTitle('not a url'), 'not a url');
      expect(fallbackTitle(''), '');
    });
  });

  group('displayTitle', () {
    test('uses the fetched title when there is one', () {
      expect(
        displayTitle(
          'Kunj Shingala | LinkedIn',
          'https://www.linkedin.com/in/kunjshingala09',
        ),
        'Kunj Shingala | LinkedIn',
      );
    });

    test('falls back to the URL-derived label when the title is empty', () {
      expect(
        displayTitle('', 'https://www.linkedin.com/in/kunjshingala09'),
        'kunjshingala09 · linkedin.com',
      );
    });
  });
}
