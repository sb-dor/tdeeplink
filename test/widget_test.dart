// Widget test: a link coming from the (fake) OS opens the right screen.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:tdeeplink/main.dart';

void main() {
  testWidgets('incoming product link opens the product screen', (tester) async {
    // A fake link stream we control instead of the real AppLinks plugin.
    final links = StreamController<Uri>();
    // Start the app with the fake stream.
    await tester.pumpWidget(App(linkStream: links.stream));
    // Let the post-frame callback subscribe to the stream.
    await tester.pump();

    // Home screen with no links yet.
    expect(find.text('Links received from the OS'), findsOneWidget);

    // "Send" a link, as the OS would.
    links.add(Uri.parse('tdeeplink://product/42?ref=email'));
    // Let the navigation animation finish.
    await tester.pumpAndSettle();

    // The product screen shows the parsed id and query.
    expect(find.text('Product'), findsOneWidget);
    expect(find.text('id: 42'), findsOneWidget);
    expect(find.text('query: {ref: email}'), findsOneWidget);

    await links.close();
  });
}
