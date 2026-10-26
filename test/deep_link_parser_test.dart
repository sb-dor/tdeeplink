// Unit tests for the Uri -> route logic. Run with: flutter test
import 'package:flutter_test/flutter_test.dart';

import 'package:tdeeplink/deep_link_parser.dart';

void main() {
  // Small helper: parse a string link.
  DeepLinkRoute parse(String link) => parseDeepLink(Uri.parse(link));

  test('custom scheme product link', () {
    final r = parse('tdeeplink://product/42?ref=email');
    expect(r.target, DeepLinkTarget.product);
    expect(r.id, '42');
    expect(r.query, {'ref': 'email'});
  });

  test('custom scheme profile link', () {
    final r = parse('tdeeplink://profile/john');
    expect(r.target, DeepLinkTarget.profile);
    expect(r.id, 'john');
  });

  test('custom scheme with empty host and a path', () {
    // tdeeplink:///product/42 has no host, only a path.
    expect(parse('tdeeplink:///product/42').target, DeepLinkTarget.product);
  });

  test('https link on our domain', () {
    final r = parse('https://$kWebHost/product/7/');
    expect(r.target, DeepLinkTarget.product);
    expect(r.id, '7');
  });

  test('root links go home', () {
    expect(parse('tdeeplink://').target, DeepLinkTarget.home);
    expect(parse('https://$kWebHost/').target, DeepLinkTarget.home);
  });

  test('unknown paths and foreign domains are unknown', () {
    expect(parse('tdeeplink://nope/what').target, DeepLinkTarget.unknown);
    expect(parse('https://other.com/product/1').target, DeepLinkTarget.unknown);
    expect(parse('tdeeplink://product').target, DeepLinkTarget.unknown);
  });
}
