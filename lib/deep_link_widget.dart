import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:tdeeplink/deep_link_parser.dart';
import 'package:tdeeplink/main.dart';

/// {@template deep_link_widget}
/// DeepLinkScope widget.
/// {@endtemplate}
class DeepLinkScope extends InheritedWidget {
  /// {@macro deep_link_widget}
  const DeepLinkScope({
    super.key, // ignore: unused_element_parameter
    required this.state,
    required super.child,
  });

  static DeepLinkWidgetState of(BuildContext context) {
    final widget = context
        .getElementForInheritedWidgetOfExactType<DeepLinkScope>()
        ?.widget;
    assert(widget != null, "No DeepLinkScope was found in element tree");
    return (widget as DeepLinkScope).state;
  }

  final DeepLinkWidgetState state;

  @override
  bool updateShouldNotify(covariant DeepLinkScope oldWidget) => false;
}

/// {@template deep_link_widget}
/// DeepLinkWidget widget.
/// {@endtemplate}
class DeepLinkWidget extends StatefulWidget {
  /// {@macro deep_link_widget}
  const DeepLinkWidget({
    super.key, // ignore: unused_element_parameter
    required this.builder,
    this.linkStream,
  });

  final WidgetBuilder builder;

  // Optional link source; null means "use AppLinks".
  final Stream<Uri>? linkStream;

  @override
  State<DeepLinkWidget> createState() => DeepLinkWidgetState();
}

/// State for widget DeepLinkWidget.
class DeepLinkWidgetState extends State<DeepLinkWidget> {
  // Every link received this session, newest first, shown on the home screen.
  final _history = ValueNotifier<List<Uri>>([]);

  ValueNotifier<List<Uri>> get history => _history;

  // Our listener on the link stream, cancelled in dispose().
  StreamSubscription<Uri>? _sub;

  /* #region Lifecycle */
  @override
  void initState() {
    super.initState();
    // Initial state initialization

    // Wait for the first frame so the Navigator exists before we push to it.
    // Links that arrive earlier are buffered by app_links, so none are lost.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // uriLinkStream gives the link that launched the app (cold start)
      // AND every link received while it is running (warm start).
      final stream = widget.linkStream ?? AppLinks().uriLinkStream;
      // Handle each link as it arrives.
      _sub = stream.listen(_handleLink);
    });
  }

  @override
  void dispose() {
    // Permanent removal of a tree stent
    // Stop listening when the app widget goes away.
    _sub?.cancel();
    // Free the notifier.
    _history.dispose();
    super.dispose();
  }
  /* #endregion */

  // Called for every incoming deep link.
  void _handleLink(Uri uri) {
    // Print to the console so you can see links in `flutter run` / logcat / Xcode.
    debugPrint('Deep link received: $uri');
    // Add to the on-screen history.
    _history.value = [uri, ..._history.value];
    // Open the screen this link points to.
    openRoute(parseDeepLink(uri));
  }

  // Pushes the screen for a parsed route.
  void openRoute(DeepLinkRoute route) {
    // Home link: pop back to the first screen instead of stacking another home.
    if (route.target == DeepLinkTarget.home) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    // Pick the screen widget for the other targets.
    final page = switch (route.target) {
      DeepLinkTarget.product => DetailPage(
        title: 'Product',
        icon: Icons.shopping_bag,
        route: route,
      ),
      DeepLinkTarget.profile => DetailPage(
        title: 'Profile',
        icon: Icons.person,
        route: route,
      ),
      _ => DetailPage(
        title: 'Unknown link',
        icon: Icons.link_off,
        route: route,
      ),
    };
    // Push that screen on top.
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // Builder gives widget.builder a context below DeepLinkScope, so it can
  // read navigatorKey via DeepLinkScope.of(context).
  @override
  Widget build(BuildContext context) =>
      DeepLinkScope(state: this, child: widget.builder(context));
}
