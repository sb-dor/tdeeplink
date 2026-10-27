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
    this.url,
  });

  final WidgetBuilder builder;

  // Optional link source; null means "use AppLinks".
  final String? url;

  @override
  State<DeepLinkWidget> createState() => DeepLinkWidgetState();
}

/// State for widget DeepLinkWidget.
// WidgetsBindingObserver = get notified by Flutter about app events, including
// links pushed by the OS (didPushRouteInformation).
class DeepLinkWidgetState extends State<DeepLinkWidget>
    with WidgetsBindingObserver {
  // Every link received this session, newest first, shown on the home screen.
  final _history = ValueNotifier<List<String>>([]);

  ValueNotifier<List<String>> get history => _history;

  /* #region Lifecycle */
  @override
  void initState() {
    super.initState();
    // Initial state initialization

    // Start receiving didPushRouteInformation (links while running, and iOS cold start).
    WidgetsBinding.instance.addObserver(this);

    // Android cold start: the launch link is in defaultRouteName.
    // Wait for the first frame so the Navigator exists before we push to it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      //
      final route =
          widget.url ??
          WidgetsBinding.instance.platformDispatcher.defaultRouteName;

      // "/" means "no launch link" (normal start, or iOS, which never uses
      // defaultRouteName for links), so there is nothing to open.
      if (route == Navigator.defaultRouteName) return;
      //
      _handleLink(route);
    });
  }

  @override
  void dispose() {
    // Stop receiving link notifications.
    WidgetsBinding.instance.removeObserver(this);
    _history.dispose();
    super.dispose();
  }
  /* #endregion */

  // Called by Flutter for every link the OS sends while the app is running
  // (Android and iOS), and for the launch link on iOS (after the first frame).
  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    // The full link, e.g. tdeeplink://product/42?ref=email.
    _handleLink(routeInformation.uri.toString());
    // true = handled; Flutter stops offering it to other observers.
    return true;
  }

  // Called for every incoming deep link.
  void _handleLink(String url) {
    // Print to the console so you can see links in `flutter run` / logcat / Xcode.
    debugPrint('Deep link received: $url');
    // Add to the on-screen history.
    _history.value = [url, ..._history.value];
    // Open the screen this link points to.
    openRoute(parseStringDeepLink(url));
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
      _ => null,
    };

    if (page == null) return;
    // Push that screen on top.
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  // Builder gives widget.builder a context below DeepLinkScope, so it can
  // read navigatorKey via DeepLinkScope.of(context).
  @override
  Widget build(BuildContext context) =>
      DeepLinkScope(state: this, child: widget.builder(context));
}
