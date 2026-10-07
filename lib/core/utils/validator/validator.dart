/// Returns a normalized HTTP(S) URL, or `null` when [url] is invalid.
///
/// URLs without a scheme are treated as HTTPS URLs so inputs such as
/// `flutter.dev` become `https://flutter.dev` consistently across the UI and
/// BLoC layers.
String? normalizeUrl(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;

  final candidate = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(candidate);

  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) return null;
  if (uri.host.isEmpty || !uri.host.contains('.')) return null;

  return uri.toString();
}

String validateUrl(String url) {
  if (url.trim().isEmpty) return 'Please enter url';
  return normalizeUrl(url) == null ? 'This is not valid url' : '';
}

/// The first http(s) link inside shared [text], or `null` when there is none.
///
/// Shopping apps share a sentence with the link at the end ("Take a look at
/// this Sandal on Flipkart https://dl.flipkart.com/s/abc", "Deal: TV
/// https://amzn.in/d/xyz"), so the whole text can't be treated as the URL.
/// Punctuation that ends the sentence is not part of the link.
String? extractSharedUrl(String text) {
  final match = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return null;

  final link = match
      .group(0)!
      .replaceFirst(RegExp(r'''[.,;:!?)\]}'"]+$'''), '');
  return normalizeUrl(link) == null ? null : link;
}
