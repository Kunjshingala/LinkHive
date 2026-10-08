import '../utils/validator/validator.dart';

/// The link inside a share-sheet event from `receive_sharing_intent`, or null.
///
/// The plugin delivers a list of shared items; for text shares the first
/// item's `path` is the shared text. A bare link is the whole text, but
/// Flipkart, Amazon and others send a sentence with the link at the end, so the
/// URL is picked out of it (see [extractSharedUrl]).
///
/// Pulled out of `ReceiveSharedIntent` so the event shapes can be unit-tested
/// without the plugin.
String? shareEventUrl(dynamic event) {
  if (event == null) return null;
  final list = event as List<dynamic>;
  if (list.isEmpty) return null;
  final path = (list.first as dynamic)?.path as String?;
  return path == null ? null : extractSharedUrl(path);
}

/// Whether the event carries anything at all (used to tell "not a link" from
/// "nothing shared", so only the former shows the "Only URL links" message).
bool shareEventHasContent(dynamic event) {
  if (event == null) return false;
  final list = event as List<dynamic>;
  return list.isNotEmpty && (list.first as dynamic)?.path != null;
}
