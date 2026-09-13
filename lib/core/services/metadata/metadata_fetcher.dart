/// Platform-specific HTML fetcher used by [LinkMetadataService].
abstract interface class MetadataFetcher {
  Future<String?> fetchHtml(Uri uri);
}
