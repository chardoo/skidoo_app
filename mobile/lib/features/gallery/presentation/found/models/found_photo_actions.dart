import 'package:jperg_app/models/photos/Photo.dart';

/// Which reactions the Found viewer's rail offers for one photo.
///
/// Two rules, and they are not the same rule. Everywhere the viewer is reached
/// from someone's *work* — discovery, search, a profile's grids, a shared
/// `/p/` link — the rail is what it has always been. Reached from **Found
/// you**, where the photo is of the viewer and may be something they have not
/// paid for, what it offers depends on the photo:
///
/// | | save | share | send | like + comment | download |
/// |---|---|---|---|---|---|
/// | free · private     | yes | yes | yes | —   | never |
/// | free · public      | yes | yes | yes | yes | never |
/// | paid · unbought    | yes | —   | —   | —   | —     |
/// | paid · bought · private | yes | yes | yes | —   | yes |
/// | paid · bought · public  | yes | yes | yes | yes | yes |
///
/// The four things that decide it:
///
/// * **Save is always on offer.** A bookmark is a reference to a photo the
///   viewer can already see — it hands them nothing they did not have, so it
///   is not something to be bought. It is the one action an unbought photo
///   still gets: "keep this where I can find it" is exactly what you want from
///   a photo you have not decided about yet. The server refuses to bookmark a
///   photo the caller cannot see, so the rule is enforced, not just honoured.
/// * **Unbought and priced** offers nothing else. Passing a photo on, or
///   writing it to the phone, is something you do with a photo that is yours.
/// * **Like and comment are public-only.** A private photo has no audience to
///   react in front of — the thread would be the viewer talking to themselves.
/// * **Download is the paid extra.** A free photo is free to look at and free
///   to pass on, but it is not free to keep, so the paid photo gets one button
///   the free one doesn't.
///
/// Save and download are separate rows above because they are separate
/// actions. They were one for a while — the bookmark glyph wrote the file to
/// the device — which made bookmarking a paid feature by accident and left the
/// viewer with no way to bookmark anything at all.
class FoundPhotoActions {
  const FoundPhotoActions._({
    required this.engagement,
    required this.commentsDisabled,
    required this.save,
    required this.share,
    required this.download,
  });

  /// Everything the rail has ever offered, subject only to the owner's
  /// engagement switch. Used by every entry point that isn't Found you.
  const FoundPhotoActions.unrestricted({required bool commentsEnabled})
      : engagement = commentsEnabled,
        commentsDisabled = !commentsEnabled,
        save = true,
        share = true,
        download = true;

  /// The Found-you rules, applied to [photo].
  factory FoundPhotoActions.forFoundPhoto(Photo photo) {
    // Free needs no transaction to be the viewer's; priced does. `isPurchased`
    // also covers a free photo already saved, but the price test alone is
    // enough to unlock and says why without needing the save to have landed.
    final unlocked = photo.price <= 0 || photo.isPurchased;
    if (!unlocked) return const FoundPhotoActions.saveOnly();

    return FoundPhotoActions._(
      engagement: photo.commentsEnabled && photo.isPublic,
      // Only where the *owner* closed the thread. A private photo shows no
      // comment glyph at all, crossed or otherwise: it has no audience by
      // rule rather than by anyone's decision, and marking every private
      // photo "comments disabled" would be noise about a thread that was
      // never on offer.
      commentsDisabled: !photo.commentsEnabled && photo.isPublic,
      save: true,
      share: true,
      // Unlocked and priced means bought — the free case was unlocked by the
      // other half of the test above, and free photos are never downloadable.
      download: photo.price > 0,
    );
  }

  /// An unbought paid photo: nothing but the bookmark.
  const FoundPhotoActions.saveOnly()
      : engagement = false,
        commentsDisabled = false,
        save = true,
        share = false,
        download = false;

  /// A rail with nothing on it. The stage renders no rail at all rather than
  /// an empty column — see [any].
  const FoundPhotoActions.none()
      : engagement = false,
        commentsDisabled = false,
        save = false,
        share = false,
        download = false;

  /// Like and comment, both live.
  final bool engagement;

  /// The comment glyph drawn unavailable, in place of [engagement]'s pair.
  /// Never true at the same time as [engagement].
  final bool commentsDisabled;

  /// Bookmark into the user's saved items. Not a download — see [download].
  final bool save;

  /// External share (OS sheet, always carrying the photo's deep link) and the
  /// in-app DM picker. They travel together: both are the viewer passing the
  /// photo on, and no rule here has ever wanted one without the other.
  final bool share;

  /// Write the file to the phone.
  final bool download;

  bool get any =>
      engagement || commentsDisabled || save || share || download;
}
