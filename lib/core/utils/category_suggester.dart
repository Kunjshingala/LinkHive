import '../../features/links/models/link_query.dart';

/// Suggests categories for a link from the site it came from.
///
/// Your own history wins: categories you already gave this site's links.
/// When there is none, a small built-in map covers a few well-known sites.
/// Pure, so the Add form and the bulk category picker share it.
class CategorySuggester {
  CategorySuggester._();

  /// Most suggestions shown at once.
  static const maxSuggestions = 3;

  /// Site name (one label of the host) → built-in category key.
  static const _defaults = <String, String>{
    'youtube': 'Watch',
    'amazon': 'Shop',
    'flipkart': 'Shop',
    'myntra': 'Shop',
    'ajio': 'Shop',
    'meesho': 'Shop',
    'airbnb': 'Travel',
    'booking': 'Travel',
    'makemytrip': 'Travel',
    'coursera': 'Learn',
    'udemy': 'Learn',
    'medium': 'Read',
    'substack': 'Read',
  };

  /// Suggested category names for a link from [host], best first.
  ///
  /// [history] is the category counts for [host]'s other links, as returned
  /// by `LinkRepository.getCategoryCountsForHost` (already filtered to names
  /// used on 2+ links). Empty [host] gets no suggestions.
  static List<String> suggest({
    required String host,
    required List<NamedCount> history,
  }) {
    if (host.isEmpty) return const [];
    if (history.isNotEmpty) {
      return history.take(maxSuggestions).map((c) => c.name).toList();
    }
    for (final label in host.split('.')) {
      final match = _defaults[label];
      if (match != null) return [match];
    }
    return const [];
  }
}
