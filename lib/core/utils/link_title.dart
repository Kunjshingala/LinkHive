/// The label to show for a link: its [title], or a readable stand-in built
/// from [url] when no title was ever fetched.
///
/// Used everywhere a link's name is drawn (LinkCard, Today, Up Next, the
/// home-screen widget) so they all agree.
String displayTitle(String title, String url) =>
    title.isNotEmpty ? title : fallbackTitle(url);

/// A readable label derived from [url] alone, e.g.
/// `https://www.linkedin.com/in/kunjshingala09?utm_source=share` →
/// `kunjshingala09 · linkedin.com`.
///
/// Some sites (LinkedIn) refuse metadata requests from anything that isn't a
/// known preview bot, so the title stays empty and the card used to show the
/// raw URL, tracking params and all. This is computed at display time and
/// never stored: a link that failed only because the device was offline must
/// still get its real title on the next fetch, and both the background
/// enrichment and "Add details" only fetch while the title is empty.
///
/// The name part is the last path segment that looks like a slug (contains
/// `-`), else the last segment, with `-`/`_` turned into spaces. Falls back to
/// the host, then to [url] itself when it can't be parsed.
String fallbackTitle(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return url;

  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) {
    host = host.substring(4);
  } else if (host.startsWith('m.')) {
    host = host.substring(2);
  }

  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.isEmpty) return host;

  final slug = segments.lastWhere(
    (s) => s.contains('-'),
    orElse: () => segments.last,
  );
  final name = slug.replaceAll(RegExp(r'[-_]+'), ' ').trim();
  return name.isEmpty ? host : '$name · $host';
}
