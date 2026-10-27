// Flutter's Material widgets.
import 'package:flutter/material.dart';
import 'package:tdeeplink/deep_link_widget.dart';

// Our Uri -> screen logic.
import 'deep_link_parser.dart';

// App entry point.
void main() {
  // Start the Flutter app.
  runApp(const App());
}

// Root widget. Stateful because it owns the link subscription.
class App extends StatefulWidget {
  // Lets tests pass a fake link stream instead of the real plugin.
  const App({super.key, this.linkStream});

  // for testing
  final Stream<Uri>? linkStream;

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deep Link Tester',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      //
      //
      // home: HomePage(),
      // builder: (context, child) => DeepLinkWidget(
      //   linkStream: widget.linkStream,
      //   builder: (context) => child!,
      // ),

      //
      //
      //
      // builder: (context, _) => DeepLinkWithAppLinksWidget(
      //   linkStream: widget.linkStream,
      //   builder: (context) => HomePage(),
      // ),
      //
      //
      //
      home: DeepLinkWidget(builder: (context) => HomePage()),
    );
  }
}

// First screen: shows the links received and lets you try links in-app.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  // Sample links for the in-app buttons.
  static final _samples = [
    Uri.parse('$kCustomScheme://product/42?ref=email'),
    Uri.parse('$kCustomScheme://profile/john'),
    Uri.parse('https://$kWebHost/product/7'),
    Uri.parse('$kCustomScheme://nope/what'),
  ];

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deep Link Tester')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Section 1: what the OS actually delivered.
          Text(
            'Links received from the OS',
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          // ValueListenableBuilder<List<Uri>>(
          //   valueListenable: DeepLinkWithAppLinksScope.of(context).history,
          //   builder: (context, links, _) => links.isEmpty
          //       // Nothing yet: tell the user how to send one.
          //       ? const Text(
          //           'None yet. Run scripts/test_deeplink.sh (see README.md).',
          //         )
          //       // Show each received link.
          //       : Column(
          //           children: [
          //             for (final uri in links)
          //               ListTile(
          //                 dense: true,
          //                 leading: const Icon(Icons.call_received),
          //                 title: Text('$uri'),
          //               ),
          //           ],
          //         ),
          // ),
          const SizedBox(height: 8),

          // Rebuild this list whenever a new link arrives.
          ValueListenableBuilder<List<String>>(
            valueListenable: DeepLinkScope.of(context).history,
            builder: (context, links, _) => links.isEmpty
                // Nothing yet: tell the user how to send one.
                ? const Text(
                    'None yet. Run scripts/test_deeplink.sh (see README.md).',
                  )
                // Show each received link.
                : Column(
                    children: [
                      for (final uri in links)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.call_received),
                          title: Text(uri),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 32),
          // Section 2: test the parser/navigation without the OS involved.
          Text(
            'Try in-app (skips the OS)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          // One button per sample link.
          for (final uri in HomePage._samples)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                // Parse and open it exactly like a real incoming link.
                onPressed: () =>
                    DeepLinkScope.of(context).openRoute(parseDeepLink(uri)),
                child: Text('$uri'),
              ),
            ),
        ],
      ),
    );
  }
}

// Screen opened by a link: shows what was parsed out of it.
class DetailPage extends StatelessWidget {
  const DetailPage({
    super.key,
    required this.title,
    required this.icon,
    required this.route,
  });

  // App bar title, e.g. "Product".
  final String title;

  // Big icon for the screen.
  final IconData icon;

  // The parsed link that opened this screen.
  final DeepLinkRoute route;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 16),
            // The id from the path, if any.
            if (route.id != null)
              Text(
                'id: ${route.id}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            // The query parameters, if any.
            if (route.query.isNotEmpty) Text('query: ${route.query}'),
            const SizedBox(height: 16),
            // The raw link, so you can compare with what you sent.
            SelectableText('link: ${route.uri}'),
          ],
        ),
      ),
    );
  }
}
