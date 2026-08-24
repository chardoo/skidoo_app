import 'package:flutter/material.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/number_format.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';

/// The faces under a request card: who has answered it, and how many.
///
/// The server sends the first few for the stack and the full count separately,
/// so "4 interested" is right even when only three faces fit.
class InterestedRow extends StatelessWidget {
  const InterestedRow({
    super.key,
    required this.interested,
    required this.count,
    required this.ext,
    this.onTap,
  });

  final List<RequestInterest> interested;
  final int count;
  final AppThemeExtension ext;

  /// Opens the full list. Only the requester can read it, so this is null on
  /// anyone else's card.
  final VoidCallback? onTap;

  /// How many faces to stack before the label carries the rest.
  static const _maxFaces = 3;

  /// Overlap, so a row of faces reads as a group rather than a list.
  static const _overlap = 10.0;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    final faces = interested.take(_maxFaces).toList();
    final label = count == 1 ? '1 interested' : '${compactCount(count)} interested';

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (faces.isNotEmpty)
          SizedBox(
            height: 26.r,
            width: (26 + (faces.length - 1) * (26 - _overlap)).r,
            child: Stack(
              children: [
                for (var i = 0; i < faces.length; i++)
                  Positioned(
                    left: i * (26 - _overlap).r,
                    child: _Face(person: faces[i], ext: ext),
                  ),
              ],
            ),
          ),
        if (faces.isNotEmpty) SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(
            color: ext.accentGold,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$label — see who answered',
      child: GestureDetector(onTap: onTap, child: row),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.person, required this.ext});

  final RequestInterest person;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final photo = person.profileUrl;
    final initial = (person.name?.trim().isNotEmpty ?? false)
        ? person.name!.trim()[0].toUpperCase()
        : '?';

    return Container(
      width: 26.r,
      height: 26.r,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // The ring is what separates one face from the one it overlaps.
        border: Border.all(color: ext.cardSurface, width: 1.5),
        color: ext.avatarBackground,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo != null && photo.isNotEmpty
          ? JpergImage(
              imageUrl: photo,
              fit: BoxFit.cover,
              // A face that will not load falls back to the initial rather
              // than a broken-image glyph in the middle of the stack.
              errorWidget: (_, __, ___) => _Initial(initial: initial, ext: ext),
            )
          : _Initial(initial: initial, ext: ext),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.initial, required this.ext});

  final String initial;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          color: ext.avatarForeground,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
