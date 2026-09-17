import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_icons.dart';

/// The Material glyphs each piece of supplied artwork stands in for.
///
/// The app draws from two families on purpose. Design's set covers the
/// stateless icons and is used wherever a glyph is chosen outright; the icon
/// font still covers everything the set has no artwork for, and every glyph
/// picked by a conditional — `editing ? check : send` cannot become artwork
/// while `send` has none to become.
const _equivalents = <String, List<IconData>>{
  AppIcons.closeMd: [Icons.close_rounded],
  AppIcons.check: [Icons.check_rounded],
  AppIcons.chevronRight: [Icons.chevron_right_rounded],
  AppIcons.add: [Icons.add_rounded, Icons.add],
  AppIcons.caretDown: [
    Icons.expand_more_rounded,
    Icons.keyboard_arrow_down_rounded,
  ],
  AppIcons.chevronUp: [Icons.keyboard_arrow_up_rounded],
  AppIcons.edit: [Icons.edit_rounded, Icons.edit_outlined],
  AppIcons.search: [Icons.search_rounded],
  AppIcons.moreVertical: [Icons.more_vert_rounded],
  AppIcons.moreHorizontal: [Icons.more_horiz_rounded],
  AppIcons.settings: [Icons.settings_outlined],
  AppIcons.trash: [Icons.delete_outline_rounded],
  AppIcons.info: [Icons.info_outline_rounded],
  AppIcons.warning: [Icons.error_outline_rounded],
  AppIcons.circleCheck: [Icons.check_circle_outline_rounded],
  AppIcons.show: [Icons.visibility_outlined],
  AppIcons.hide: [Icons.visibility_off_outlined],
  AppIcons.clock: [Icons.access_time_rounded, Icons.schedule_rounded],
  AppIcons.mail: [Icons.mail_outline_rounded],
  AppIcons.camera: [
    Icons.camera_alt_rounded,
    Icons.camera_alt,
    Icons.photo_camera_outlined,
    Icons.photo_camera_rounded,
  ],
  AppIcons.qrCode: [Icons.qr_code_scanner_rounded],
  AppIcons.mapPin: [Icons.place_outlined, Icons.place_rounded],
  AppIcons.externalLink: [Icons.open_in_new_rounded],
  AppIcons.redo: [Icons.refresh_rounded],
  AppIcons.filter: [Icons.tune_rounded],
};

/// Finds a glyph by what it *means*, not by which family drew it.
///
/// `find.byIcon` stopped seeing the stateless glyphs when they moved to the
/// artwork. Matching both the artwork and the font glyph it replaced is what
/// keeps an assertion about a control — "the row ends in a chevron" — true of
/// the control rather than of the icon set that happened to be in use when it
/// was written.
Finder findAppIcon(String asset) {
  final fallbacks = _equivalents[asset] ?? const <IconData>[];
  return find.byWidgetPredicate(
    (w) =>
        (w is AppSvgIcon && w.asset == asset) ||
        (w is Icon && fallbacks.contains(w.icon)),
    description: 'the $asset glyph',
  );
}
