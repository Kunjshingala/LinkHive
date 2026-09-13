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
