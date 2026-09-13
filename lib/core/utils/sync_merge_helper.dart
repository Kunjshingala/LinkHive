import '../../features/links/models/link_model.dart';
import '../utils/utils.dart';

class SyncMergeHelper {
  /// Returns fields changed on both sides from the same base version.
  static List<String> conflictingFields({
    required LinkModel base,
    required LinkModel local,
    required LinkModel cloud,
  }) {
    final fields = <String>[];
    if (base.title != local.title &&
        base.title != cloud.title &&
        local.title != cloud.title) {
      fields.add('title');
    }
    if (base.url != local.url &&
        base.url != cloud.url &&
        local.url != cloud.url) {
      fields.add('url');
    }
    if (base.description != local.description &&
        base.description != cloud.description &&
        local.description != cloud.description) {
      fields.add('description');
    }
    if (base.image != local.image &&
        base.image != cloud.image &&
        local.image != cloud.image) {
      fields.add('image');
    }
    if (base.priority != local.priority &&
        base.priority != cloud.priority &&
        local.priority != cloud.priority) {
      fields.add('priority');
    }
    return fields;
  }

  /// Performs a 3-way merge between [base], [local], and [cloud] states of a Link.
  ///
  /// Returns the merged [LinkModel]. If no merge was needed (cloud and local identical),
  /// returns the cloud link.
  /// The `isSynced` flag will be set to `false` if any local edits were preserved
  /// against the cloud state, signaling that the merged result needs to be pushed up.
  static LinkModel merge({
    required LinkModel base,
    required LinkModel local,
    required LinkModel cloud,
  }) {
    // If local hasn't changed since last sync, just take cloud
    if (_isEqual(base, local)) {
      return cloud;
    }

    // Identify which fields changed locally vs base
    final titleChangedLocally = base.title != local.title;
    final urlChangedLocally = base.url != local.url;
    final descChangedLocally = base.description != local.description;
    final imageChangedLocally = base.image != local.image;
    final priorityChangedLocally = base.priority != local.priority;

    // Identify which fields changed on cloud vs base
    final titleChangedCloud = base.title != cloud.title;
    final urlChangedCloud = base.url != cloud.url;
    final descChangedCloud = base.description != cloud.description;
    final imageChangedCloud = base.image != cloud.image;
    final priorityChangedCloud = base.priority != cloud.priority;

    // Resolve conflicts (Cloud wins on direct collisions)
    final resolvedTitle = (titleChangedLocally && !titleChangedCloud)
        ? local.title
        : cloud.title;
    final resolvedUrl = (urlChangedLocally && !urlChangedCloud)
        ? local.url
        : cloud.url;
    final resolvedDesc = (descChangedLocally && !descChangedCloud)
        ? local.description
        : cloud.description;
    final resolvedImage = (imageChangedLocally && !imageChangedCloud)
        ? local.image
        : cloud.image;
    final resolvedPriority = (priorityChangedLocally && !priorityChangedCloud)
        ? local.priority
        : cloud.priority;

    // Merge Categories using Set Math
    final baseCats = base.categories.toSet();
    final localCats = local.categories.toSet();
    final cloudCats = cloud.categories.toSet();

    final addedLocally = localCats.difference(baseCats);
    final removedLocally = baseCats.difference(localCats);
    final addedCloud = cloudCats.difference(baseCats);
    final removedCloud = baseCats.difference(cloudCats);

    var resolvedCats = baseCats.toSet();
    resolvedCats.addAll(addedLocally);
    resolvedCats.addAll(addedCloud);
    resolvedCats.removeAll(removedLocally);
    resolvedCats.removeAll(removedCloud);

    // Build the merged link
    final mergedLink = cloud.copyWith(
      title: resolvedTitle,
      url: resolvedUrl,
      description: resolvedDesc,
      image: resolvedImage,
      priority: resolvedPriority,
      categories: resolvedCats.toList(),
    );

    // If the merged link differs from the cloud link, it means we kept some local edits.
    // We must flag it as unsynced so SyncService pushes it back to the cloud.
    if (!_isEqual(mergedLink, cloud)) {
      printLog(
        tag: 'SyncMergeHelper',
        msg:
            'Merged local changes into cloud link ${mergedLink.id}. Marking as unsynced.',
      );
      return mergedLink.copyWith(isSynced: false);
    }

    return mergedLink.copyWith(isSynced: true);
  }

  /// Checks if a link was edited locally by comparing it to its base state.
  static bool hasLocalEdits(LinkModel base, LinkModel local) {
    return !_isEqual(base, local);
  }

  /// Simple equality check for merge purposes (ignores timestamps and sync flags)
  static bool _isEqual(LinkModel a, LinkModel b) {
    if (a.title != b.title) return false;
    if (a.url != b.url) return false;
    if (a.description != b.description) return false;
    if (a.image != b.image) return false;
    if (a.priority != b.priority) return false;

    final aCats = a.categories.toSet();
    final bCats = b.categories.toSet();
    if (aCats.length != bCats.length || !aCats.containsAll(bCats)) return false;

    return true;
  }
}
