import 'package:equatable/equatable.dart';

/// Which links a Library list shows by read state.
enum ReadFilter { all, unread, read }

/// Order of a Library list.
///
/// [newest] and [oldest] sort by save time and are the only orders that show
/// month headers.
enum LinkSort { newest, oldest, priority, mostSaved, site }

/// Everything that decides which links a Library list shows and in what order.
///
/// Empty sets and a null [host] mean "no filter". Quick-saved (Inbox) links
/// are never included; they live in the Inbox until they get details.
class LinkQuery extends Equatable {
  const LinkQuery({
    this.search = '',
    this.categories = const {},
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

  /// A link matches when its priority is any of these (`'High'`, `'Normal'`,
  /// `'Low'`), compared case-insensitively.
  final Set<String> priorities;

  /// Source site as returned by `sourceHost`, e.g. `youtube.com`.
  final String? host;

  final ReadFilter readFilter;

  /// Only links saved at least this many times. 2 backs the "Saved 2×+" tile.
  final int minShareCount;

  final LinkSort sort;

  /// How many filters the filter sheet has turned on, for the badge on the
  /// filter button. Search, read state and sort are shown elsewhere.
  int get activeFilterCount =>
      categories.length + priorities.length + (host == null ? 0 : 1);

  LinkQuery copyWith({
    String? search,
    Set<String>? categories,
    Set<String>? priorities,
    String? host,
    bool clearHost = false,
    ReadFilter? readFilter,
    int? minShareCount,
    LinkSort? sort,
  }) => LinkQuery(
    search: search ?? this.search,
    categories: categories ?? this.categories,
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
    priorities,
    host,
    readFilter,
    minShareCount,
    sort,
  ];
}

/// The counts behind the Library overview tiles. Inbox links are excluded.
class LibraryStats extends Equatable {
  const LibraryStats({
    this.total = 0,
    this.unread = 0,
    this.high = 0,
    this.savedTwicePlus = 0,
    this.read = 0,
  });

  final int total;
  final int unread;
  final int high;
  final int savedTwicePlus;
  final int read;

  @override
  List<Object?> get props => [total, unread, high, savedTwicePlus, read];
}

/// A name with how many links have it: a source host or a category.
class NamedCount extends Equatable {
  const NamedCount(this.name, this.count);

  final String name;
  final int count;

  @override
  List<Object?> get props => [name, count];
}
