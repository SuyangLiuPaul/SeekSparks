import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:seeksparks/models/app_settings.dart';
import 'package:seeksparks/providers/main_provider.dart';
import 'package:seeksparks/widgets/retired_version_notice.dart';

/// `RetiredVersionNotice` must return its child UNWRAPPED.
///
/// This is a structural ratchet, not a rendering test. It sits directly
/// above `_RootRouter` in `home:`, and `_RootRouter` keeps "the splash
/// has been shown" and "the boot deep link has been handled" in STATIC
/// fields precisely because a wrapper appearing or disappearing here
/// would move the router in the element tree and throw its state away.
/// The notice speaks through a SnackBar for that reason. If it ever
/// grows a banner, `_RootRouter`'s comment stops being true and the
/// boot-link latch has to be reconsidered — so this fails first.
void main() {
  testWidgets('the notice never wraps its child', (tester) async {
    final child = Container(key: const ValueKey('the-child'));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(
          home: RetiredVersionNotice(child: child),
        ),
      ),
    );

    final notice = find.byType(RetiredVersionNotice);
    expect(notice, findsOneWidget);
    // The notice's DIRECT child, not its descendants: a Container
    // builds a LimitedBox and a ConstrainedBox of its own, and asking
    // for descendants counted those and failed a passing app. What is
    // being ratcheted is whether anything sits BETWEEN the notice and
    // the child it was handed.
    final directChildren = <Widget>[];
    tester
        .element(notice)
        .visitChildElements((e) => directChildren.add(e.widget));
    expect(directChildren.length, 1,
        reason: 'expected exactly the child, got: '
            '${directChildren.map((w) => w.runtimeType).toList()}');
    expect(directChildren.single, same(child));
  });
}
