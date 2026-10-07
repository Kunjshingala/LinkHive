import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/utils/url_canonical.dart';

/// Duplicate matching, seeded from links actually saved in LinkHive
/// (2026-10-07). Each case is either the same link shared twice (must match)
/// or two different links that look alike (must not match). A false match is
/// worse than a missed duplicate: it hides one of the user's links.
void main() {
  void expectSame(String a, String b) =>
      expect(canonicalUrl(a), canonicalUrl(b), reason: '$a\n  vs\n$b');

  void expectDifferent(String a, String b) =>
      expect(canonicalUrl(a), isNot(canonicalUrl(b)), reason: '$a\n  vs\n$b');

  group('Instagram', () {
    test('same reel with different stkn share tokens matches', () {
      expectSame(
        'https://www.instagram.com/reel/DeKio97zfoF/?stkn=aW4yNHE1cm9ubW00',
        'https://www.instagram.com/reel/DeKio97zfoF/?stkn=c29tZXRoaW5nZWxzZQ',
      );
    });

    test('a profile with stkn matches the plain profile', () {
      expectSame(
        'https://www.instagram.com/thevarunmayya?stkn=NHZ1aXl4Ymk0b3Fl',
        'https://instagram.com/thevarunmayya',
      );
    });

    test('legacy igsh tokens are ignored too', () {
      expectSame(
        'https://www.instagram.com/reel/DbxzESYyF3_/?igsh=MWM3djJla2l0MXRpdw==',
        'https://www.instagram.com/reel/DbxzESYyF3_/?stkn=MWM3djJla2l0MXRpdw==',
      );
    });

    test('different reels do not match', () {
      expectDifferent(
        'https://www.instagram.com/reel/DeKio97zfoF/?stkn=aW4yNHE1cm9ubW00',
        'https://www.instagram.com/reel/DbxzESYyF3_/?stkn=aW4yNHE1cm9ubW00',
      );
    });

    test('a reel is never folded into a post with the same code', () {
      expectDifferent(
        'https://www.instagram.com/reel/DeKio97zfoF/',
        'https://www.instagram.com/p/DeKio97zfoF/',
      );
    });
  });

  group('YouTube', () {
    test('same video: youtu.be with si, with t, and the watch URL', () {
      const a = 'https://youtu.be/Px_3O3KeR24?si=D1aFI2KXKKo0u0ob';
      const b = 'https://youtu.be/Px_3O3KeR24?t=293&si=UzI6xOOWvJbDNkl_';
      expectSame(a, b);
      expectSame(a, 'https://www.youtube.com/watch?v=Px_3O3KeR24');
      expectSame(a, 'https://m.youtube.com/watch?v=Px_3O3KeR24&feature=share');
    });

    test('shorts fold into the watch URL', () {
      expectSame(
        'https://youtube.com/shorts/LObzlk67yI4?si=JasHbeqoVBGnz4Zm',
        'https://www.youtube.com/watch?v=LObzlk67yI4',
      );
    });

    test('different videos do not match', () {
      expectDifferent(
        'https://youtu.be/Px_3O3KeR24?si=D1aFI2KXKKo0u0ob',
        'https://youtu.be/3mnhueXepdM?si=ODjoAm7TvUAizcgb',
      );
    });

    test('a playlist position stays part of the link', () {
      expectDifferent(
        'https://www.youtube.com/watch?v=Px_3O3KeR24&list=PL1',
        'https://www.youtube.com/watch?v=Px_3O3KeR24&list=PL2',
      );
    });

    test('a community post keeps its own path', () {
      const post =
          'http://youtube.com/post/UgkxzTNOczNYuVNuo4qUkNUaoFVbgfoLqJZM?si=3EkH8O0RyDVOLOyN';
      expectSame(
        post,
        'https://www.youtube.com/post/UgkxzTNOczNYuVNuo4qUkNUaoFVbgfoLqJZM',
      );
      expect(canonicalUrl(post), contains('/post/'));
      expect(canonicalUrl(post), isNot(contains('/watch')));
    });
  });

  group('shopping links', () {
    test('Shopify search-position params are ignored', () {
      expectSame(
        'https://www.headphonezone.in/products/jcally-jm12?_pos=1&_fid=c6805647a&_ss=c',
        'https://www.headphonezone.in/products/jcally-jm12',
      );
    });

    test('different Shopify products do not match', () {
      expectDifferent(
        'https://www.headphonezone.in/products/jcally-jm12?_pos=1&_fid=c6805647a&_ss=c',
        'https://www.headphonezone.in/products/fiio-x-jade-audio-ja11?_pos=2&_fid=c6805647a&_ss=c',
      );
    });

    test('Flipkart: same pid and lid match despite a new pageUID', () {
      expectSame(
        'https://www.flipkart.com/apple-airpods-pro-3-bluetooth/p/itm4a09e10dfed93?pid=ACCHNFX2FDJQXSXZ&lid=LSTACCHNFX2FDJQXSXZJBZI81&marketplace=FLIPKART&BU=Mixed&pageUID=1791343324500',
        'https://www.flipkart.com/apple-airpods-pro-3-bluetooth/p/itm4a09e10dfed93?pid=ACCHNFX2FDJQXSXZ&lid=LSTACCHNFX2FDJQXSXZJBZI81&pageUID=1791399999999',
      );
    });

    test('Flipkart: a different variant (pid) does not match', () {
      expectDifferent(
        'https://www.flipkart.com/apple-airpods-pro-3-bluetooth/p/itm4a09e10dfed93?pid=ACCHNFX2FDJQXSXZ&pageUID=1',
        'https://www.flipkart.com/apple-airpods-pro-3-bluetooth/p/itm4a09e10dfed93?pid=ACCHOTHERVARIANT&pageUID=1',
      );
    });

    test('Google srsltid and utm params are ignored, affiliate cid is kept', () {
      const base =
          'https://luxury.tatacliq.com/sennheiser-ie-200-wired-in-ear-audiophile-headphones-black-in-the-ear/p-mp000000030311042';
      expectSame(
        '$base?srsltid=AfmBOorKw2Xab&utm_content=YT3-wkknL&utm_source=youtube&cid=YTaffiliate',
        '$base?cid=YTaffiliate',
      );
      expectDifferent('$base?cid=YTaffiliate', base);
    });
  });

  group('per-host keys only apply on their own hosts', () {
    test('si is kept off YouTube/Spotify', () {
      expectDifferent(
        'https://example.com/page?si=1',
        'https://example.com/page?si=2',
      );
    });

    test('stkn and pageUID are kept on other hosts', () {
      expectDifferent(
        'https://example.com/a?stkn=1',
        'https://example.com/a?stkn=2',
      );
      expectDifferent(
        'https://example.com/a?pageUID=1',
        'https://example.com/a?pageUID=2',
      );
    });

    test('a look-alike host does not get YouTube rules', () {
      expectDifferent(
        'https://notyoutube.com/watch?v=a&si=1',
        'https://notyoutube.com/watch?v=a&si=2',
      );
    });
  });

  group('general normalization', () {
    test('http and https, www and trailing slash are ignored', () {
      expectSame(
        'http://www.github.com/Kunjshingala/',
        'https://github.com/Kunjshingala',
      );
    });

    test('param order is ignored', () {
      expectSame(
        'https://example.com/a?x=1&y=2',
        'https://example.com/a?y=2&x=1',
      );
    });

    test('an all-tracking query equals no query', () {
      expectSame(
        'https://www.linkedin.com/in/kunjshingala03/?utm_source=share',
        'https://www.linkedin.com/in/kunjshingala03/',
      );
    });

    test('plain anchors are ignored, hash routes are not', () {
      expectSame(
        'https://dart.dev/blog/google-summer-of-code-2026-results#results',
        'https://dart.dev/blog/google-summer-of-code-2026-results',
      );
      expectDifferent(
        'https://app.example.com/#/item/1',
        'https://app.example.com/#/item/2',
      );
    });

    test('unknown params are kept as part of the link', () {
      expectDifferent(
        'https://wellfound.com/jobs?role=1',
        'https://wellfound.com/jobs?role=2',
      );
    });

    test('path case is kept', () {
      expectDifferent(
        'https://x.com/KunjShingala_09',
        'https://x.com/kunjshingala_09',
      );
    });

    test('a scheme-less URL matches its https form', () {
      expectSame('whitelabelfox.com', 'https://whitelabelfox.com/');
    });
  });

  group('exact keys for real saved links', () {
    test('produces the expected matching key', () {
      const cases = {
        'https://www.instagram.com/reel/DeKio97zfoF/?stkn=aW4yNHE1cm9ubW00':
            'https://instagram.com/reel/DeKio97zfoF',
        'https://youtu.be/Px_3O3KeR24?t=293&si=UzI6xOOWvJbDNkl_':
            'https://youtube.com/watch?v=Px_3O3KeR24',
        'https://youtube.com/shorts/LObzlk67yI4?si=JasHbeqoVBGnz4Zm':
            'https://youtube.com/watch?v=LObzlk67yI4',
        'http://youtube.com/post/UgkxzTNOczNYuVNuo4qUkNUaoFVbgfoLqJZM?si=3EkH8O0RyDVOLOyN':
            'https://youtube.com/post/UgkxzTNOczNYuVNuo4qUkNUaoFVbgfoLqJZM',
        'https://www.flipkart.com/google-pixel-buds-2a-bluetooth/p/itm8928d5d2b1881?pid=ACCHGFZWVGZZXYBV&lid=LSTACCHGFZWVGZZXYBVJVYNMQ&hl_lid=&marketplace=FLIPKART&fm=eyJ3dHAiOiJyZWNvIn0%3D&pageUID=1791343334457':
            'https://flipkart.com/google-pixel-buds-2a-bluetooth/p/itm8928d5d2b1881?lid=LSTACCHGFZWVGZZXYBVJVYNMQ&pid=ACCHGFZWVGZZXYBV',
        'https://luxury.tatacliq.com/x/p-mp1?srsltid=Afm&utm_content=YT&utm_source=youtube&cid=YTaffiliate':
            'https://luxury.tatacliq.com/x/p-mp1?cid=YTaffiliate',
        'https://www.headphonezone.in/products/headphone-zone-x-ddhifi-hi-res-dac?_pos=3&_fid=c6805647a&_ss=c':
            'https://headphonezone.in/products/headphone-zone-x-ddhifi-hi-res-dac',
        'https://www.amazon.in/Godrej-Comprehensive-1-5T-HIC-18Q3TH/dp/B0GMD5NPX6':
            'https://amazon.in/Godrej-Comprehensive-1-5T-HIC-18Q3TH/dp/B0GMD5NPX6',
      };
      cases.forEach(
        (input, key) => expect(canonicalUrl(input), key, reason: input),
      );
    });
  });

  group('known limitations', () {
    test(
      'Facebook share short-links get a new code per share and do not match',
      () {
        expectDifferent(
          'https://www.facebook.com/share/r/1FGkCPD78X/',
          'https://www.facebook.com/share/r/9ZzOtherCode/',
        );
      },
    );
  });
}
