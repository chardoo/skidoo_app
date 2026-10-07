import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/config/legal_links.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/presentation/pages/face_capture_step_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The face sits in the middle of the screen, not the middle of its own box.
///
/// [OnboardingStepScaffold] arranges a step in a `CrossAxisAlignment.start`
/// column, which is what the title and subtitle want, and drops the body in
/// under an `Expanded` — main axis only — inside a scroll view. So the body's
/// width constraint is loose, and a Column that centres its children centres
/// them across its own shrink-wrapped width: in this case the width of the
/// legal links, pinned to the left margin. The illustration looked badly
/// off-centre while being, locally, perfectly centred.
///
/// Asserted as a position rather than "a SizedBox is present", because the
/// width is the only reason this lands in the middle and it is exactly the
/// sort of wrapper a later tidy-up deletes as redundant.
class _FakeAuth extends AuthService {
  @override
  Future<String> getName() async => 'Ama';
}

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
        home: child,
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
    sl.registerSingleton<AuthService>(_FakeAuth());
  });

  tearDown(() {
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
  });

  testWidgets('the face illustration is centred on the screen', (t) async {
    await t.pumpWidget(host(const FaceCaptureStepPage(standalone: true)));
    await t.pumpAndSettle();

    final screen = t.getSize(find.byType(MaterialApp)).width;
    final circle = t.getCenter(find.byType(DottedCircle));

    expect(
      circle.dx,
      moreOrLessEquals(screen / 2, epsilon: 1.0),
      reason: 'it was sitting at the centre of the legal-links row instead',
    );
  });

  testWidgets('and so is the legal links row under it', (t) async {
    await t.pumpWidget(host(const FaceCaptureStepPage(standalone: true)));
    await t.pumpAndSettle();

    final screen = t.getSize(find.byType(MaterialApp)).width;

    // The row, not either link: the two labels are different lengths, so the
    // midpoint between their centres is not the middle of the row.
    expect(
      t.getCenter(find.byType(LegalLinksRow)).dx,
      moreOrLessEquals(screen / 2, epsilon: 1.0),
    );
  });
}
