import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The supplied icon set, as paths.
///
/// Vectors at 24×24, so they are crisp at whatever size a surface draws them —
/// which is why these replaced the 20 px PNGs that arrived first: a 20 px
/// bitmap drawn at 24 logical points is upscaled 3.6× on a 3× phone, and looks
/// it.
///
/// Named for what they are rather than where they came from. The files are
/// grouped into folders by the tool that exported them, and a path like
/// `assets/ico/Interface/Heart_01.svg` is not something a call site should
/// have to know or keep right.
///
/// The set is **outlines only**. That matters for anything with an on/off
/// state: the rail says "you liked this" by changing the glyph's shape, not
/// only its colour — see `reaction_buttons_transparent_test`, and the reason,
/// which is that colour alone says nothing to a reader who cannot separate red
/// from white. Until a filled heart and bookmark exist, the active half of
/// those two still comes from the icon font.
class AppIcons {
  const AppIcons._();

  static const _root = 'assets/ico';

  // ── Engagement ────────────────────────────────────────────────────────────
  static const like = '$_root/Interface/Heart_01.svg';
  static const comment = '$_root/Communication/Chat_Circle.svg';
  static const save = '$_root/Interface/Bookmark.svg';
  static const share = '$_root/Communication/Paper_Plane.svg';

  // ── Chrome ────────────────────────────────────────────────────────────────
  static const search = '$_root/Interface/Search_Magnifying_Glass.svg';
  static const settings = '$_root/Interface/Settings.svg';
  static const star = '$_root/Interface/Star.svg';
  static const trash = '$_root/Interface/Trash_Full.svg';
  static const externalLink = '$_root/Interface/External_Link.svg';
  static const check = '$_root/Interface/Check.svg';

  static const bell = '$_root/Communication/Bell.svg';
  static const mail = '$_root/Communication/Mail.svg';
  static const conversation = '$_root/Communication/Chat_Conversation_Circle.svg';

  static const add = '$_root/Edit/Add_Plus.svg';
  static const edit = '$_root/Edit/Edit_Pencil_01.svg';
  static const filter = '$_root/Edit/Filter.svg';
  static const show = '$_root/Edit/Show.svg';
  static const hide = '$_root/Edit/Hide.svg';
  static const redo = '$_root/Edit/Redo.svg';

  static const closeSm = '$_root/Menu/Close_SM.svg';
  static const closeMd = '$_root/Menu/Close_MD.svg';
  static const closeLg = '$_root/Menu/Close_LG.svg';
  static const moreHorizontal = '$_root/Menu/More_Horizontal.svg';
  static const moreVertical = '$_root/Menu/More_Vertical.svg';

  static const home = '$_root/Navigation/House_01.svg';
  static const mapPin = '$_root/Navigation/Map_Pin.svg';
  static const user = '$_root/User/User_02.svg';
  static const camera = '$_root/System/Camera.svg';
  static const qrCode = '$_root/System/Qr_Code.svg';
  static const clock = '$_root/Calendar/Clock.svg';

  static const caretDown = '$_root/Arrow/Caret_Down_SM.svg';
  static const chevronRight = '$_root/Arrow/Chevron_Right_MD.svg';
  static const chevronUp = '$_root/Arrow/Chevron_Up_Duo.svg';

  static const info = '$_root/Warning/Info.svg';
  static const warning = '$_root/Warning/Circle_Warning.svg';
  static const circleCheck = '$_root/Warning/Circle_Check.svg';
}

/// One of [AppIcons], drawn the way [Icon] draws an icon-font glyph.
///
/// Two things [SvgPicture] does not do on its own, and a rail needs both:
///
///  * **Tint.** The artwork ships with a grey stroke baked in, which is the
///    exporter's colour and not the app's. A source-in filter replaces it, so
///    the same file serves a white glyph over a photo and a gold one on a
///    sheet.
///  * **The drop shadow.** Every glyph over media carries a tight offset
///    shadow to separate it from a bright image — `Icon` takes that as a
///    parameter and `SvgPicture` has nowhere to put it, so it is drawn here as
///    an offset dark copy beneath the tinted one. That is what a text shadow
///    is anyway.
class AppSvgIcon extends StatelessWidget {
  const AppSvgIcon(
    this.asset, {
    super.key,
    this.size,
    this.color,
    this.shadows,
  });

  final String asset;

  /// Null takes the ambient [IconTheme], exactly as [Icon] does.
  ///
  /// Both of these are nullable for one reason: this is a drop-in for `Icon`,
  /// and most call sites give it neither — they let the surrounding theme
  /// decide. A widget that defaulted to, say, white would have been silently
  /// wrong on every light background it was swapped into.
  final double? size;
  final Color? color;

  /// Matched to what [Icon] is given at the same call site, so a rail mixing
  /// supplied artwork and font glyphs cannot end up with two shadows on it.
  final List<Shadow>? shadows;

  Widget _glyph(Color tint, double dimension) => SvgPicture.asset(
        asset,
        width: dimension,
        height: dimension,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
      );

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final dimension = size ?? theme.size ?? 24;
    final tint = color ?? theme.color ?? Colors.white;

    final cast = shadows ?? const <Shadow>[];
    if (cast.isEmpty) return _glyph(tint, dimension);

    return Stack(
      children: [
        for (final shadow in cast)
          Transform.translate(
            offset: shadow.offset,
            child: _glyph(shadow.color, dimension),
          ),
        _glyph(tint, dimension),
      ],
    );
  }
}
