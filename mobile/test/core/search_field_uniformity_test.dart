import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/search_field.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/widgets/chat_search_field.dart';

/// Every search box in the app is the same control, and the control is the
/// chat search field.
///
/// There were five drawings of it: the chat row, the glass pill, the Search
/// screen's own bar, the forward sheet's borderless filled box, and a form
/// field wearing a search icon in the location picker. They disagreed on
/// height, corner radius, fill, border weight, icon colour and size, text
/// size, and whether there was a clear button at all — so the same act looked
/// like a different control depending on which screen you were standing on.
///
/// One difference survived, and only because it has to: the glass fill is
/// translucent (white 10% / black 5%) for sitting over a photo, and on an
/// opaque page it nearly disappears. So the tint follows the surface and
/// nothing else does.
Widget _host(AppThemeExtension ext, Widget child, {double width = 300}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: [ext]),
        home:
            Scaffold(body: Center(child: SizedBox(width: width, child: child))),
      ),
    );

BoxDecoration _pill(WidgetTester t) {
  final container = t.widgetList<Container>(find.byType(Container)).firstWhere(
        (c) => c.decoration is BoxDecoration,
      );
  return container.decoration! as BoxDecoration;
}

void main() {
  for (final (name, ext) in <(String, AppThemeExtension)>[
    ('dark', AppThemeExtension.dark),
    ('light', AppThemeExtension.light),
  ]) {
    group(name, () {
      testWidgets('both surfaces are the same shape', (t) async {
        final radii = <double>[];
        for (final surface in SearchFieldSurface.values) {
          await t.pumpWidget(_host(
            ext,
            SearchField(controller: TextEditingController(), surface: surface),
          ));
          final shape = _pill(t).borderRadius! as BorderRadius;
          radii.add(shape.topLeft.x);
        }

        // A pill on one screen and a rounded rectangle on another was the most
        // visible half of this.
        expect(radii.first, radii.last);
      });

      testWidgets('both surfaces are the same height', (t) async {
        final heights = <double>[];
        for (final surface in SearchFieldSurface.values) {
          await t.pumpWidget(_host(
            ext,
            SearchField(controller: TextEditingController(), surface: surface),
          ));
          heights.add(t.getSize(find.byType(SearchField)).height);
        }

        expect(heights.first, heights.last);
      });

      testWidgets('the glass surface is translucent', (t) async {
        await t.pumpWidget(_host(
          ext,
          SearchField(
            controller: TextEditingController(),
            surface: SearchFieldSurface.glass,
          ),
        ));

        // If this ever becomes opaque it has stopped being usable over a photo,
        // which is the only reason the two variants exist.
        expect(_pill(t).color!.a, lessThan(1.0));
      });

      testWidgets('a field defaults to the opaque page surface', (t) async {
        await t.pumpWidget(_host(
          ext,
          SearchField(controller: TextEditingController()),
        ));

        // Four call sites — the share sheet, the member picker and both
        // creator headers — sat on a flat background wearing the translucent
        // fill, purely because glass used to be the default. A 5%-black field
        // on a light page is invisible.
        expect(_pill(t).color, ext.searchFieldFill);
        expect(_pill(t).color!.a, 1.0);
      });

      testWidgets('the clear button needs no handler from the caller',
          (t) async {
        final controller = TextEditingController();
        await t.pumpWidget(_host(ext, SearchField(controller: controller)));
        expect(find.byIcon(Icons.cancel), findsNothing);

        controller.text = 'wedding';
        await t.pump();

        // The share sheet was the one search box you could not empty, because
        // clearing was something each caller had to remember to wire up.
        expect(find.byIcon(Icons.cancel), findsOneWidget);

        await t.tap(find.byIcon(Icons.cancel));
        await t.pump();
        expect(controller.text, isEmpty);
      });

      testWidgets('the magnifier keeps its place once there is text',
          (t) async {
        final controller = TextEditingController();
        await t.pumpWidget(_host(ext, SearchField(controller: controller)));
        final empty = t.getTopLeft(find.byType(TextField));

        controller.text = 'wedding';
        await t.pump();

        // The chat field gave the magnifier's slot to the clear button, so the
        // query slid left by the width of an icon on the first keystroke.
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);
        expect(t.getTopLeft(find.byType(TextField)), empty);
      });

      testWidgets('the outline marks focus', (t) async {
        final focusNode = FocusNode();
        await t.pumpWidget(_host(
          ext,
          SearchField(
            controller: TextEditingController(),
            focusNode: focusNode,
          ),
        ));
        expect(_pill(t).border!.top.color, isNot(ext.accentGold));

        focusNode.requestFocus();
        await t.pump();

        expect(_pill(t).border!.top.color, ext.accentGold);
      });

      testWidgets('every field offers the search key', (t) async {
        await t.pumpWidget(_host(
          ext,
          SearchField(controller: TextEditingController()),
        ));

        expect(t.widget<TextField>(find.byType(TextField)).textInputAction,
            TextInputAction.search);
      });

      testWidgets('the chat row is the shared field plus a Cancel', (t) async {
        await t.pumpWidget(_host(
          ext,
          ChatSearchField(
            controller: TextEditingController(),
            onChanged: (_) {},
            onCancel: () {},
            autofocus: false,
          ),
          // This row carries a Cancel as well as the field, so it needs a real
          // phone's width rather than the 300 the bare field is measured in.
          width: 390,
        ));

        // Chat is where this treatment came from; it must not drift back into
        // being its own drawing of it.
        expect(find.byType(SearchField), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });
    });
  }
}
