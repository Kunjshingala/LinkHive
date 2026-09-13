import '../../utils/utils.dart';
import 'metadata_fetcher.dart';
import 'metadata_fetcher_io.dart'
    if (dart.library.html) 'metadata_fetcher_web.dart';

/// Result of a metadata fetch attempt.
class LinkMetadata {
  final String title;
  final String image;
  final String description;

  const LinkMetadata({this.title = '', this.image = '', this.description = ''});
}

/// Fetches basic page metadata using a platform-specific transport.
class LinkMetadataService {
  LinkMetadataService({MetadataFetcher? fetcher}) : _fetcher = fetcher ?? MetadataFetcherImpl();

  final MetadataFetcher _fetcher;

  /// Fetches metadata and falls back gracefully when the page cannot be read.
  Future<LinkMetadata> fetchMetadata(String url) async {
    try {
      final uri = Uri.parse(url);
      final html = await _fetcher.fetchHtml(uri);
      if (html == null) return const LinkMetadata();

      final title =
          _extractMeta(html, 'og:title') ?? _extractMeta(html, 'twitter:title') ?? _extractTitle(html) ?? uri.host;
      final image =
          _resolveUrl(uri, _extractMeta(html, 'og:image')) ??
          _resolveUrl(uri, _extractMeta(html, 'twitter:image')) ??
          _resolveUrl(uri, _extractIcon(html)) ??
          _defaultFaviconUrl(uri) ??
          '';
      final description = _extractMeta(html, 'og:description') ?? _extractMeta(html, 'twitter:description') ?? '';

      return LinkMetadata(title: title, image: image, description: description);
    } catch (e) {
      printLog(tag: 'LinkMetadataService', msg: 'fetchMetadata error: $e');
      return const LinkMetadata();
    }
  }

  String? _extractMeta(String html, String property) {
    final patterns = [
      RegExp(
        '''<meta[^>]+property=['"]${RegExp.escape(property)}['"][^>]+content=['"]([^'"]+)['"]''',
        caseSensitive: false,
      ),
      RegExp(
        '''<meta[^>]+name=['"]${RegExp.escape(property)}['"][^>]+content=['"]([^'"]+)['"]''',
        caseSensitive: false,
      ),
      RegExp(
        '''<meta[^>]+content=['"]([^'"]+)['"][^>]+property=['"]${RegExp.escape(property)}['"]''',
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

  String? _extractIcon(String html) {
    final linkTags = RegExp(r'<link\b[^>]*>', caseSensitive: false).allMatches(html);
    for (final match in linkTags) {
      final tag = match.group(0)!;
      final rel = _extractAttribute(tag, 'rel')?.toLowerCase().split(RegExp(r'\s+')) ?? const [];
      if (!rel.contains('icon') && !rel.contains('shortcut')) continue;

      final href = _extractAttribute(tag, 'href');
      if (href != null && href.isNotEmpty) return href;
    }
    return null;
  }

  String? _extractAttribute(String tag, String attribute) {
    final match = RegExp(
      '''${RegExp.escape(attribute)}\\s*=\\s*['"]([^'"]+)['"]''',
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1)?.trim();
  }

  String? _resolveUrl(Uri baseUri, String? value) {
    if (value == null || value.isEmpty) return null;

    final resolved = baseUri.resolve(value);
    if (resolved.scheme != 'http' && resolved.scheme != 'https') return null;
    return resolved.toString();
  }

  String? _defaultFaviconUrl(Uri uri) {
    if (uri.host.isEmpty) return null;
    return uri.replace(path: '/favicon.ico', query: '', fragment: '').toString();
  }
}
