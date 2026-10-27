// Pure Dart: turns an incoming deep link Uri into an app route.
// It has no Flutter imports, so it is easy to unit test (see test/deep_link_parser_test.dart).

// Our own custom URL scheme. Must match AndroidManifest.xml and ios/Runner/Info.plist.
const String kCustomScheme = 'tdeeplink';

// The domain used for https links (Android App Links / iOS Universal Links).
// TODO: replace with the domain where you host .well-known/* (see docs/).
const String kWebHost = 'example.com';

// The screens a deep link can open.
enum DeepLinkTarget { home, product, profile, unknown }

// The result of parsing: which screen to open, plus any data for it.
class DeepLinkRoute {
  // Creates a parsed route.
  const DeepLinkRoute(this.target, {this.id, this.query = const {}, required this.uri});

  // Which screen to open.
  final DeepLinkTarget target;

  // The path parameter, e.g. "42" in /product/42 or "john" in /profile/john.
  final String? id;

  // Query parameters, e.g. {ref: email} from ?ref=email.
  final Map<String, String> query;

  // The original link, kept so the UI can show exactly what arrived.
  final Uri uri;
}

// Converts a Uri into a DeepLinkRoute.
DeepLinkRoute parseDeepLink(Uri uri) {
  // Collect the meaningful path pieces of the link.
  final List<String> segments;

  // Custom scheme: tdeeplink://product/42 -> host "product", path "/42".
  if (uri.scheme == kCustomScheme) {
    // So we treat the host as the first segment: [product, 42].
    segments = [if (uri.host.isNotEmpty) uri.host, ...uri.pathSegments];
    // https link: https://example.com/product/42 -> path segments [product, 42].
  } else if ((uri.scheme == 'https' || uri.scheme == 'http') && uri.host == kWebHost) {
    // The host is just our domain, so only the path matters.
    segments = uri.pathSegments;
    // Any other scheme or domain is not ours.
  } else {
    // Show it on the "unknown link" screen instead of crashing.
    return DeepLinkRoute(DeepLinkTarget.unknown, uri: uri);
  }

  // Drop empty pieces caused by trailing slashes, e.g. /product/42/.
  final parts = segments.where((s) => s.isNotEmpty).toList();

  // No path at all (tdeeplink:// or https://example.com/) -> home screen.
  if (parts.isEmpty) {
    return DeepLinkRoute(DeepLinkTarget.home, query: uri.queryParameters, uri: uri);
  }

  // /product/<id> -> product screen.
  if (parts.length == 2 && parts[0] == 'product') {
    return DeepLinkRoute(DeepLinkTarget.product, id: parts[1], query: uri.queryParameters, uri: uri);
  }

  // /profile/<username> -> profile screen.
  if (parts.length == 2 && parts[0] == 'profile') {
    return DeepLinkRoute(DeepLinkTarget.profile, id: parts[1], query: uri.queryParameters, uri: uri);
  }

  // Ours, but a path we don't know.
  return DeepLinkRoute(DeepLinkTarget.unknown, query: uri.queryParameters, uri: uri);
}


// Converts a String link into a DeepLinkRoute.
DeepLinkRoute parseStringDeepLink(String url) {
  // tryParse returns null instead of throwing on malformed text (e.g. "http://[bad").
  final uri = Uri.tryParse(url.trim());
  // Not a valid link at all: show it on the "unknown link" screen, keeping the raw text.
  if (uri == null) {
    return DeepLinkRoute(DeepLinkTarget.unknown, uri: Uri(path: url));
  }
  // Valid Uri: reuse the same rules as parseDeepLink, so both always agree.
  return parseDeepLink(uri);
}