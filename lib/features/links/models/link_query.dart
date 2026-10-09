import 'package:equatable/equatable.dart';

/// Which links the Links list shows by read state.
enum ReadFilter { all, unread, read }

/// Order of the Links list.
///
/// [newest] and [oldest] sort by save time and show date headers. [site]
/// groups links under one header per site, sites with the most links first.
enum LinkSort { newest, oldest, priority, mostSaved, site }

/// The quick chips above the Links list. Each one is a preset over
/// [LinkQuery.readFilter], [LinkQuery.priorities] and
/// [LinkQuery.minShareCount]; picking one replaces the others.
enum QuickFilter { all, unread, high, savedTwice, read }

/// Everything that decides which links the Links list shows and in what order.
///
/// Empty sets, a null [host] and `false` [uncategorized] mean "no filter".
/// Quick-saved (Inbox) links are never included; they live in the Inbox until
/// they get details.
class LinkQuery extends Equatable {
  const LinkQuery({
    this.search = '',
    this.categories = const {},
    this.uncategorized = false,
    this.priorities = const {},
    this.host,
    this.readFilter = ReadFilter.all,
    this.minShareCount = 0,
    this.sort = LinkSort.newest,
  });

  /// Matched against title, description and URL, case-insensitive.
  final String search;

  /// A link matches when it has **any** of these category names.
  final Set<String> categories;

  /// Only links with no category at all ("No category" in the sheet).
  final bool uncategorized;

  /// A link matches when its priority is any of these (`'High'`, `'Normal'`,
  /// `'Low'`), compared case-insensitively.
  final Set<String> priorities;

  /// Source site as returned by `sourceHost`, e.g. `youtube.com`.
  final String? host;

  final ReadFilter readFilter;

  /// Only links saved at least this many times. 2 backs "Saved 2×+".
  final int minShareCount;

  final LinkSort sort;

  /// The quick chip this query matches, or [QuickFilter.all] when it matches
  /// none of the presets exactly.
  QuickFilter get quickFilter {
    final high = priorities.length == 1 &&
        priorities.single.toLowerCase() == 'high';
    if (minShareCount >= 2 && readFilter == ReadFilter.all && priorities.isEmpty) {
      return QuickFilter.savedTwice;
    }
    if (high && readFilter == ReadFilter.all && minShareCount == 0) {
      return QuickFilter.high;
    }
    if (priorities.isEmpty && minShareCount == 0) {
      return switch (readFilter) {
        ReadFilter.unread => QuickFilter.unread,
        ReadFilter.read => QuickFilter.read,
        ReadFilter.all => QuickFilter.all,
      };
    }
    return QuickFilter.all;
  }

  /// This query with [quick] applied, keeping search, source, category and
  /// sort.
  LinkQuery withQuickFilter(QuickFilter quick) => LinkQuery(
    search: search,
    categories: categories,
    uncategorized: uncategorized,
    host: host,
    sort: sort,
    readFilter: switch (quick) {
      QuickFilter.unread => ReadFilter.unread,
      QuickFilter.read => ReadFilter.read,
      _ => ReadFilter.all,
    },
    priorities: quick == QuickFilter.high ? const {'High'} : const {},
    minShareCount: quick == QuickFilter.savedTwice ? 2 : 0,
  );

  /// True when anything narrows the list, so it's worth showing how many
  /// links match.
  bool get hasFilters =>
      search.trim().isNotEmpty ||
      categories.isNotEmpty ||
      uncategorized ||
      host != null ||
      priorities.isNotEmpty ||
      readFilter != ReadFilter.all ||
      minShareCount > 0;

  LinkQuery copyWith({
    String? search,
    Set<String>? categories,
    bool? uncategorized,
    Set<String>? priorities,
    String? host,
    bool clearHost = false,
    ReadFilter? readFilter,
    int? minShareCount,
    LinkSort? sort,
  }) => LinkQuery(
    search: search ?? this.search,
    categories: categories ?? this.categories,
    uncategorized: uncategorized ?? this.uncategorized,
    priorities: priorities ?? this.priorities,
    host: clearHost ? null : (host ?? this.host),
    readFilter: readFilter ?? this.readFilter,
    minShareCount: minShareCount ?? this.minShareCount,
    sort: sort ?? this.sort,
  );

  @override
  List<Object?> get props => [
    search,
    categories,
    uncategorized,
    priorities,
    host,
    readFilter,
    minShareCount,
    sort,
  ];
}

/// The counts behind the quick chips. Inbox links are excluded.
class LibraryStats extends Equatable {
  const LibraryStats({
    this.total = 0,
    this.unread = 0,
    this.high = 0,
    this.savedTwicePlus = 0,
    this.read = 0,
    this.uncategorized = 0,
  });

  final int total;
  final int unread;
  final int high;
  final int savedTwicePlus;
  final int read;

  /// Links with no category, for "No category" in the Category sheet.
  final int uncategorized;

  int countFor(QuickFilter quick) => switch (quick) {
    QuickFilter.all => total,
    QuickFilter.unread => unread,
    QuickFilter.high => high,
    QuickFilter.savedTwice => savedTwicePlus,
    QuickFilter.read => read,
  };

  @override
  List<Object?> get props => [
    total,
    unread,
    high,
    savedTwicePlus,
    read,
    uncategorized,
  ];
}

/// A name with how many links have it: a source host or a category.
class NamedCount extends Equatable {
  const NamedCount(this.name, this.count);

  final String name;
  final int count;

  @override
  List<Object?> get props => [name, count];
}
