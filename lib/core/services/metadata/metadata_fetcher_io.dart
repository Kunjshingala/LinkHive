import 'dart:convert';

import 'package:http/http.dart' as http;

import 'metadata_fetcher.dart';

/// Direct website fetcher for mobile and desktop platforms.
class MetadataFetcherImpl implements MetadataFetcher {
  static const _timeout = Duration(seconds: 8);

  @override
  Future<String?> fetchHtml(Uri uri) async {
    final client = http.Client();
    try {
      final response = await client
          .get(uri, headers: const {'User-Agent': 'LinkHive/1.0 (metadata-fetcher)'})
          .timeout(_timeout);
      if (response.statusCode != 200) return null;
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } finally {
      client.close();
    }
  }
}
