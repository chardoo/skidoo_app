import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/presentation/pages/create_request_flow.dart';

/// What Done does on "Your request is live!".
///
/// It is the last thing anybody touches in this flow, and it used to put them
/// back on the request form — the form for the request they had just been
/// congratulated for publishing, which reads as the publish having been undone.
///
/// The cause was the confirmation being a route of its own, pushed over the
/// form with `pushReplacement`: that disposes the route it replaces, so the
/// code waiting to dismiss the form resumed in a dead State and never ran, and
/// the replaced route's future completed with null rather than success so the
/// form was never told either. One pop then landed on the form underneath.
///
/// The confirmation takes over the flow's own route now, which is what makes
/// Done a way out rather than a step back.
void main() {
  // A phone, not the 800x600 the test binding defaults to: the confirmation is
  // a full-height column and overflows that surface, which throws before a tap
  // can land on the button at the bottom of it.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  Widget host({required VoidCallback onLaunch, required List<String> log}) =>
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    final result = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) =>
                            const CreateRequestFlow(startPublished: true),
                      ),
                    );
                    log.add('returned:$result');
                    onLaunch();
                  },
                  child: const Text('Request a photographer'),
                ),
              ),
            ),
          ),
        ),
      );

  testWidgets('Done leaves the flow instead of stepping back into the form',
      (tester) async {
    final log = <String>[];
    await tester.pumpWidget(host(onLaunch: () {}, log: log));

    await tester.tap(find.text('Request a photographer'));
    await tester.pumpAndSettle();
    expect(find.text('Your request is live!'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    // Back where the flow was started from — not on a form, and not on the
    // confirmation either.
    expect(find.text('Request a photographer'), findsOneWidget);
    expect(find.text('Your request is live!'), findsNothing);
    expect(find.text('New Request'), findsNothing);
  });

  testWidgets('Done reports that something was published', (tester) async {
    // So a board that was showing a list can refresh because of it. The flow
    // used to resolve to null however it ended, which made "published" and
    // "backed out" indistinguishable to the caller.
    final log = <String>[];
    await tester.pumpWidget(host(onLaunch: () {}, log: log));

    await tester.tap(find.text('Request a photographer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(log, ['returned:true']);
  });

  testWidgets('the back gesture does the same thing', (tester) async {
    // Whatever Done does, Back has to do too: both leave a screen that is only
    // reporting something already finished, and the form must not be under it.
    final log = <String>[];
    await tester.pumpWidget(host(onLaunch: () {}, log: log));

    await tester.tap(find.text('Request a photographer'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Request a photographer'), findsOneWidget);
    expect(find.text('New Request'), findsNothing);
  });
}
