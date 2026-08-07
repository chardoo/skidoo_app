import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

/// The swap: when a mounted [JpergImage] is handed a different url, the image
/// already on screen has to stay there as the new one's placeholder so the two
/// cross-dissolve. Without it the slot falls back to `placeholder` — meaning a
/// carousel, filmstrip or recycled tile blinks through a blank or a spinner
/// between two photos.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(body: SizedBox(width: 200, height: 200, child: child)),
      );

  CachedNetworkImage loaded(WidgetTester t) =>
      t.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

  testWidgets('holds the outgoing image while the next one decodes',
      (t) async {
    await t.pumpWidget(host(const JpergImage(
      imageUrl: 'https://cdn.example.com/a.jpg',
    )));

    expect(loaded(t).useOldImageOnUrlChange, isTrue);
  });

  testWidgets('cross-dissolves over swapDuration', (t) async {
    const swap = Duration(milliseconds: 420);
    await t.pumpWidget(host(const JpergImage(
      imageUrl: 'https://cdn.example.com/a.jpg',
      swapDuration: swap,
    )));

    // fadeOut is the outgoing half of the dissolve; fadeIn is the arriving one.
    expect(loaded(t).fadeOutDuration, swap);
    expect(loaded(t).fadeInDuration, const Duration(milliseconds: 250));
  });

  testWidgets('Duration.zero opts back out to a hard cut', (t) async {
    await t.pumpWidget(host(const JpergImage(
      imageUrl: 'https://cdn.example.com/a.jpg',
      swapDuration: Duration.zero,
    )));

    expect(loaded(t).useOldImageOnUrlChange, isFalse);
  });

  testWidgets('a url change swaps in place rather than remounting', (t) async {
    await t.pumpWidget(host(const JpergImage(
      imageUrl: 'https://cdn.example.com/a.jpg',
    )));
    final before = t.element(find.byType(CachedNetworkImage));

    await t.pumpWidget(host(const JpergImage(
      imageUrl: 'https://cdn.example.com/b.jpg',
    )));

    // Same element, new url: the widget was updated, not rebuilt from scratch,
    // which is the precondition for the old image being available to fade out.
    expect(t.element(find.byType(CachedNetworkImage)), same(before));
    expect(loaded(t).imageUrl, contains('b.jpg'));
  });
}
