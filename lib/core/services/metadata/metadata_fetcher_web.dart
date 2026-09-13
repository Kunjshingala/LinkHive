import 'package:http/http.dart' as http;

import 'metadata_fetcher.dart';

/// Web fetcher that delegates website access to a CORS-safe backend proxy.
///
/// Configure with:
/// `--dart-define=LINKHIVE_METADATA_API=https://api.example.com/metadata`
class MetadataFetcherImpl implements MetadataFetcher {
  static const _metadataApi = String.fromEnvironment('LINKHIVE_METADATA_API');
  static const _timeout = Duration(seconds: 8);

  @override
  Future<String?> fetchHtml(Uri uri) async {
    if (_metadataApi.isEmpty) return null;
    final base = Uri.parse(_metadataApi);
    final endpoint = base.replace(queryParameters: {...base.queryParameters, 'url': uri.toString()});
    final response = await http.get(endpoint, headers: const {'Accept': 'text/html'}).timeout(_timeout);
    if (response.statusCode != 200) return null;
    return response.body;
  }
}
