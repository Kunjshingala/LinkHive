import 'validator/validator.dart';

/// Query keys that only ever mean "who shared this / which ad sent you".
///
/// Stripped on every host. Keys starting with `utm_` are stripped too.
/// The `_pos`/`_fid`/`_ss`/`_sid`/`_psq` group is Shopify's search-result
/// tracking; the leading underscore keeps collisions with real params unlikely.
const _globalTrackingKeys = {
  'fbclid',
  'gclid',
  'gbraid',
  'wbraid',
  'msclkid',
  'ttclid',
  'twclid',
  'yclid',
  'igsh',
  'igshid',
  'mc_eid',
  'mc_cid',
  '_hsenc',
  '_hsmi',
  'li_fat_id',
  'srsltid',
  '_pos',
  '_fid',
  '_ss',
  '_sid',
  '_psq',
};

/// Generic-looking keys that are only trackers on these hosts.
///
/// Matched against the host and its subdomains (see [_hostMatches]); on any
/// other host the same key is treated as part of the link's identity.
const _perHostTrackingKeys = <String, Set<String>>{
  'youtube.com': {'si', 't', 'feature', 'pp'},
  'youtu.be': {'si', 't', 'feature', 'pp'},
  'open.spotify.com': {'si'},
  'instagram.com': {'stkn'},
  'twitter.com': {'ref_src', 'ref_url'},
  'x.com': {'ref_src', 'ref_url'},
  'aliexpress.com': {'spm'},
  'aliexpress.us': {'spm'},
  'alibaba.com': {'spm'},
  'flipkart.com': {'pageUID', 'marketplace', 'BU', 'fm', 'hl_lid'},
};

/// YouTube paths whose second segment is a video id: `/shorts/X` etc.
const _youtubeVideoPathPrefixes = {'shorts', 'live', 'embed'};

/// Returns a key that is equal for two URLs pointing at the same content.
///
/// Used **only** to detect duplicates. It is never stored or shown: links are
/// saved exactly as shared, so affiliate params survive (see
/// `docs/designs/smart-duplicate-merge.md` §1).
///
/// It ignores tracking params, `http` vs `https`, a `www.`/`m.` prefix, a
/// trailing `/`, param order and plain `#anchors`, and folds YouTube's short
/// forms (`youtu.be/X`, `/shorts/X`, `/live/X`, `/embed/X`) into
/// `youtube.com/watch?v=X`. Anything it doesn't recognise is kept: missing a
/// duplicate is better than merging two different links.
String canonicalUrl(String url) {
  final normalized = normalizeUrl(url) ?? url.trim();
  final uri = Uri.tryParse(normalized);
  if (uri == null || uri.host.isEmpty) return normalized;

  final rawHost = uri.host.toLowerCase();
  final dropKeys = <String>{
    for (final entry in _perHostTrackingKeys.entries)
      if (_hostMatches(rawHost, entry.key)) ...entry.value,
  };

  final params = <String>[];
  String? youtubeVideoId;
  for (final segment in uri.query.split('&')) {
    if (segment.isEmpty) continue;
    final key = _decode(segment.split('=').first);
    if (key.startsWith('utm_') || _globalTrackingKeys.contains(key)) continue;
    if (dropKeys.contains(key)) continue;
    if (key == 'v' && _isYoutube(rawHost)) {
      youtubeVideoId = _decode(segment.substring(segment.indexOf('=') + 1));
      continue;
    }
    params.add(segment);
  }

  var host = _stripPrefix(rawHost);
  var path = uri.path;

  if (_isYoutube(rawHost)) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (rawHost == 'youtu.be' && segments.isNotEmpty) {
      youtubeVideoId = segments.first;
    } else if (segments.length >= 2 &&
        _youtubeVideoPathPrefixes.contains(segments.first)) {
      youtubeVideoId = segments[1];
    } else if (!(segments.length == 1 && segments.first == 'watch')) {
      // A post, channel, playlist or handle page: keep its own path, and keep
      // any `v` we pulled out since it isn't a watch page.
      if (youtubeVideoId != null) params.add('v=$youtubeVideoId');
      youtubeVideoId = null;
    }
    if (youtubeVideoId != null) {
      host = 'youtube.com';
      path = '/watch';
      params.add('v=$youtubeVideoId');
    }
  }

  if (path.endsWith('/')) path = path.substring(0, path.length - 1);
  params.sort();

  final port = uri.hasPort ? ':${uri.port}' : '';
  final query = params.isEmpty ? '' : '?${params.join('&')}';
  final fragment = uri.fragment.startsWith('/') || uri.fragment.startsWith('!/')
      ? '#${uri.fragment}'
      : '';
  return 'https://$host$port$path$query$fragment';
}

bool _hostMatches(String host, String domain) =>
    host == domain || host.endsWith('.$domain');

bool _isYoutube(String host) =>
    _hostMatches(host, 'youtube.com') || host == 'youtu.be';

String _stripPrefix(String host) {
  if (host.startsWith('www.')) return host.substring(4);
  if (host.startsWith('m.')) return host.substring(2);
  return host;
}

/// Decodes a query key or value; malformed `%` escapes are compared raw.
String _decode(String component) {
  try {
    return Uri.decodeQueryComponent(component);
  } on ArgumentError {
    return component;
  } on FormatException {
    return component;
  }
}
