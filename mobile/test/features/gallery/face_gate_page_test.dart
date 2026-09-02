import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/face_gate_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/face_gate_prompt.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The gate in front of scanning a code.
///
/// Scanning answers "are there photos of me in here?", and face matching needs
/// a reference selfie to answer it with. Without one the scan used to run
/// anyway and come back empty — which reads as an event holding no photos of
/// you, not as a missing selfie, so nothing on screen said what to do about it.
///
/// The gate has to be exactly as strict as [resolveFoundAccess]: too strict and
/// it asks people who already have a face on file for another one; too loose
/// and the scan it lets through cannot match anything.
class _FakeAuth extends AuthService {
  _FakeAuth({required this.token, required this.hasFaces});

  final String token;
  final bool hasFaces;

  @override
  Future<String> getToken() async => token;

  @override
  Future<bool> getHasAddedFaces() async => hasFaces;
}

void main() {
  void register(_FakeAuth auth) {
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
    sl.registerSingleton<AuthService>(auth);
  }

  // The default 800x600 test surface makes ScreenUtil scale every .sp value
  // against a 390dp design width, roughly doubling the layout and pushing the
  // button off-screen. Size the surface like the phone the design targets.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// Pumps a page that opens the gate and records what it answered.
  Future<List<bool?>> openGate(WidgetTester tester) async {
    final answers = <bool?>[];
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, _) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async =>
                    answers.add(await FaceGatePage.show(context)),
                child: const Text('scan'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('scan'));
    await tester.pumpAndSettle();
    return answers;
  }

  testWidgets('a user with no face is asked for one', (tester) async {
    register(_FakeAuth(token: 'jwt', hasFaces: false));

    await openGate(tester);

    expect(find.text('Add your face to get found'), findsOneWidget);
    // Signed in already, so the panel asks only for the selfie — an
    // "Already have an account? Sign in" line here would be nonsense.
    expect(find.text('Take a selfie'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('it is the Found tab\'s gate, word for word', (tester) async {
    // The same rule is being explained, so it gets the same screen. This
    // asserts the default copy rather than a scan-specific rewording: the
    // moment this page starts passing its own title or subtitle, there are two
    // explanations of one rule and they drift.
    register(_FakeAuth(token: 'jwt', hasFaces: false));

    await openGate(tester);

    final prompt = tester.widget<FaceGatePrompt>(find.byType(FaceGatePrompt));
    expect(prompt.title, isNull);
    expect(prompt.subtitle, isNull);
    expect(prompt.actionLabel, isNull);
    expect(
      find.text(
        'Upload a selfie so we can match you in photos from events you attend.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a guest is asked to sign up, with a way back to sign in',
      (tester) async {
    register(_FakeAuth(token: '', hasFaces: false));

    await openGate(tester);

    expect(find.text('Add your face to get found'), findsOneWidget);
    expect(find.text('Add my face'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('a user who already has a face is not stopped', (tester) async {
    // The gate must be invisible to everyone it does not apply to: it pops
    // straight back with permission to carry on, so the scan they tapped for
    // still opens.
    register(_FakeAuth(token: 'jwt', hasFaces: true));

    final answers = await openGate(tester);

    expect(answers, [true]);
    expect(find.byType(FaceGatePrompt), findsNothing);
  });

  testWidgets('backing out of the gate does not let the scan through',
      (tester) async {
    register(_FakeAuth(token: 'jwt', hasFaces: false));

    final answers = await openGate(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // False, not null-treated-as-true: the caller reads this to decide whether
    // to open the scanner, and a dismissed gate must not open it.
    expect(answers, [false]);
  });
}
