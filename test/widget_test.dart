// Widget tests: links coming from the OS open the right screen.
// They use Flutter's built-in deep link path (no packages), the same one the
// Android and iOS engines use.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tdeeplink/main.dart';

// Sends a link exactly like the engine does: a "pushRouteInformation" call on
// the flutter/navigation channel. Flutter turns it into didPushRouteInformation.
Future<void> sendOsLink(WidgetTester tester, String link) async {
  // Encode the call with the navigation channel's own codec (JSON).
  final message = SystemChannels.navigation.codec.encodeMethodCall(
    MethodCall('pushRouteInformation', {'location': link}),
  );
  // Deliver it as if it came from the platform side.
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    message,
    (_) {},
  );
}

void main() {
  testWidgets(
    'link while running (warm start, and iOS cold start) opens the product screen',
    (tester) async {
      // Start the app normally (no launch link).
      await tester.pumpWidget(const App());
      // Let the post-frame callback run.
      await tester.pump();

      // Home screen with no links yet.
      expect(find.text('Links received from the OS'), findsOneWidget);

      // "Tap" a link, as the OS would.
      await sendOsLink(tester, 'tdeeplink://product/42?ref=email');
      // Let the navigation animation finish.
      await tester.pumpAndSettle();

      // The product screen shows the parsed id and query.
      expect(find.text('Product'), findsOneWidget);
      expect(find.text('id: 42'), findsOneWidget);
      expect(find.text('query: {ref: email}'), findsOneWidget);
    },
  );

  testWidgets(
    'launch link in defaultRouteName (Android cold start) opens the profile screen',
    (tester) async {
      // On Android the launch link arrives as the initial route.
      tester.platformDispatcher.defaultRouteNameTestValue =
          'tdeeplink://profile/john';
      // Reset it so other tests start without a launch link.
      addTearDown(tester.platformDispatcher.clearDefaultRouteNameTestValue);

      // Start the app; DeepLinkWidget reads defaultRouteName after the first frame.
      await tester.pumpWidget(const App());
      await tester.pumpAndSettle();

      // The profile screen shows the parsed username.
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('id: john'), findsOneWidget);
    },
  );
}
