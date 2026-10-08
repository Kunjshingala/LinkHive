import '../models/link_model.dart';

/// What [LinkManager.saveOrMerge] did with a link.
sealed class SaveResult {
  const SaveResult();
}

/// No saved link matched, so [link] was stored as a new record.
class SaveCreated extends SaveResult {
  const SaveCreated(this.link);

  final LinkModel link;
}

/// The link was already saved, so the share was merged into it.
///
/// [previous] is the record before the merge; [LinkManager.undoMerge] needs
/// it to revert. [addedVersion] is true when the share brought a URL the
/// record didn't have yet (it went into [LinkModel.otherUrls]).
class SaveMerged extends SaveResult {
  const SaveMerged({
    required this.merged,
    required this.previous,
    required this.addedVersion,
  });

  final LinkModel merged;
  final LinkModel previous;
  final bool addedVersion;
}
