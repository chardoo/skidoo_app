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

    final label = count == 1 ? '1 interested' : '${compactCount(count)} interested';
    final labelStyle = TextStyle(
      color: ext.accentGold,
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
    );

    // How many faces are drawn depends on the room there is, because the two
    // halves of this row are not equally worth keeping: the count is the
    // information — "4 interested" is the whole point — and the faces are
    // decoration on top of it. A fixed three overflowed a narrow card by 12 px
    // and Flutter striped the corner of it.
    //
    // So the faces are dropped one at a time until the label fits, rather than
    // the label being truncated to "4 inter…" beside a full set of avatars.
    final row = LayoutBuilder(
      builder: (context, constraints) {
        final gap = 8.w;
        final step = (26 - _overlap).r;
        final faceWidth = 26.r;

        var fit = interested.length < _maxFaces ? interested.length : _maxFaces;
        if (constraints.maxWidth.isFinite) {
          // Measured rather than estimated: the label's width depends on the
          // count's digits and the platform's font, and guessing it is how a
          // row like this comes to overflow by twelve pixels.
          final painter = TextPainter(
            text: TextSpan(text: label, style: labelStyle),
            textDirection: Directionality.of(context),
            maxLines: 1,
          )..layout();

          while (fit > 0) {
            final stack = faceWidth + (fit - 1) * step;
            if (stack + gap + painter.width <= constraints.maxWidth) break;
            fit--;
          }
        }

        final faces = interested.take(fit).toList();
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (faces.isNotEmpty) ...[
              SizedBox(
                height: 26.r,
                width: faceWidth + (faces.length - 1) * step,
                child: Stack(
                  children: [
                    for (var i = 0; i < faces.length; i++)
                      Positioned(
                        left: i * step,
                        child: _Face(person: faces[i], ext: ext),
                      ),
                  ],
                ),
              ),
              SizedBox(width: gap),
            ],
            // The last guard. With every face dropped the label still has to
            // fit whatever is left, and a card narrow enough to defeat that
            // should ellipsize rather than stripe.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
          ],
        );
      },
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
