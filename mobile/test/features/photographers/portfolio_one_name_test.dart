import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/portfolio_form.dart';

/// The portfolio form's name field, and what it is called.
///
/// It was labelled "Studio name" and hinted "Username", for a field whose
/// value is simply what the account is called — and it posted `studio_name`,
/// a second name column beside `name`. Nothing agreed on which of the two to
/// show: this editor wrote one, the search row read it, the server's
/// `display_name()` read the other first, and the web portal let a
/// photographer set them to different strings.
///
/// One name now (see the backend's app/utils/account_name.py), so there is one
/// field, called what it is. The `name` the form reports is what
/// `UpdatePhotographerProfileUseCase` sends.
Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 2400 * 3);
    view.devicePixelRatio = 3;
  });

  testWidgets('the field is labelled Name, and there is one of it',
      (t) async {
    await t.pumpWidget(_host(PortfolioForm(onChanged: (_) {})));
    await t.pump();

    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Studio name'), findsNothing);
    // The hint said "Username", which the account's handle is — and it is
    // generated server-side and never typed here.
    expect(find.text('Username'), findsNothing);
  });

  testWidgets('an existing name prefills it', (t) async {
    await t.pumpWidget(
      _host(PortfolioForm(onChanged: (_) {}, initialName: 'Mensah Studios')),
    );
    await t.pump();

    expect(find.text('Mensah Studios'), findsOneWidget);
  });

  testWidgets('what it reports is the name, trimmed', (t) async {
    PortfolioFormData? latest;
    await t.pumpWidget(_host(PortfolioForm(onChanged: (d) => latest = d)));
    await t.pump();

    await t.enterText(find.byType(TextField).first, '  Mensah Studios  ');
    await t.pump();

    expect(latest?.name, 'Mensah Studios');
  });

  testWidgets('the studio cover photo is untouched by the merge', (t) async {
    // A studio's cover picture is a real second thing, and nobody asked for
    // that to be merged — so it keeps its own label and its own control.
    await t.pumpWidget(_host(PortfolioForm(onChanged: (_) {})));
    await t.pump();

    expect(find.text('Studio cover photo (optional)'), findsOneWidget);
  });
}
