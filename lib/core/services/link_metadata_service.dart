import 'dart:io';

import '../utils/utils.dart';

/// Result of a metadata fetch attempt.
class LinkMetadata {
  final String title;
  final String image;
  final String description;

  const LinkMetadata({this.title = '', this.image = '', this.description = ''});
}

/// Fetches basic Open Graph metadata (title, image) from a URL.
/// Falls back gracefully — never throws to callers.
class LinkMetadataService {
  static const _timeout = Duration(seconds: 8);

  Future<LinkMetadata> fetchMetadata(String url) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = _timeout;
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'LinkHive/1.0 (metadata-fetcher)');
      final response = await request.close();

      if (response.statusCode != 200) return const LinkMetadata();

      final html = await response.transform(const SystemEncoding().decoder).join();
      client.close();

      final title =
          _extractMeta(html, 'og:title') ?? _extractMeta(html, 'twitter:title') ?? _extractTitle(html) ?? uri.host;

      final image = _extractMeta(html, 'og:image') ?? _extractMeta(html, 'twitter:image') ?? '';
      final description = _extractMeta(html, 'og:description') ?? _extractMeta(html, 'twitter:description') ?? '';

      return LinkMetadata(title: title, image: image, description: description);
    } catch (e) {
      printLog(tag: 'LinkMetadataService', msg: 'fetchMetadata error: $e');
      return const LinkMetadata();
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────

  String? _extractMeta(String html, String property) {
    // Match <meta property="og:title" content="..." />
    final patterns = [
      RegExp(
        '<meta[^>]+property=[\'"]${RegExp.escape(property)}[\'"][^>]+content=[\'"]([^\'"]+)[\'"]',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+name=[\'"]${RegExp.escape(property)}[\'"][^>]+content=[\'"]([^\'"]+)[\'"]',
        caseSensitive: false,
      ),
      // content before property
      RegExp(
        '<meta[^>]+content=[\'"]([^\'"]+)[\'"][^>]+property=[\'"]${RegExp.escape(property)}[\'"]',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(html);
      final value = match?.group(1)?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _extractTitle(String html) {
    final match = RegExp('<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(html);
    return match?.group(1)?.trim();
  }
}
