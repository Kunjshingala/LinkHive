import 'package:flutter_test/flutter_test.dart';
import 'package:link_hive/core/utils/url_canonical.dart';

void main() {
  test('strips www. and m. prefixes', () {
    expect(sourceHost('https://www.instagram.com/reel/abc/'), 'instagram.com');
    expect(sourceHost('https://m.youtube.com/watch?v=abc'), 'youtube.com');
  });

  test('folds youtu.be into youtube.com', () {
    expect(sourceHost('https://youtu.be/Px_3O3KeR24?si=x'), 'youtube.com');
  });

  test('keeps other subdomains', () {
    expect(sourceHost('https://docs.google.com/document/d/1'), 'docs.google.com');
  });

  test('is case-insensitive and handles a missing scheme', () {
    expect(sourceHost('WWW.Amazon.in/dp/B0CX23V2ZK'), 'amazon.in');
  });

  test('returns an empty string when there is no host', () {
    expect(sourceHost('not a url'), '');
    expect(sourceHost(''), '');
  });
}
