String validateUrl(String url) {
  if (url.trim().isEmpty) return 'Please enter url';

  Uri? uri = Uri.tryParse(url);

  if (uri == null || (uri.scheme != 'http' && uri.scheme == 'https')) {
    return 'This is not valid url';
  } else {
    return '';
  }
}
