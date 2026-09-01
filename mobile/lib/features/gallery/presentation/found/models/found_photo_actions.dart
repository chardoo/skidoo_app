import 'package:jperg_app/models/photos/Photo.dart';

/// Which reactions the Found viewer's rail offers for one photo.
///
/// Two rules, and they are not the same rule. Everywhere the viewer is reached
/// from someone's *work* — discovery, search, a profile's grids, a shared
/// `/p/` link — the rail is what it has always been. Reached from **Found
/// you**, where the photo is of the viewer and may be something they have not
/// paid for, what it offers depends on the photo:
///
/// | | share | send | like + comment | download |
/// |---|---|---|---|---|
/// | free · private     | yes | yes | —   | never |
/// | free · public      | yes | yes | yes | never |
/// | paid · unbought    | —   | —   | —   | —     |
/// | paid · bought · private | yes | yes | —   | yes |
/// | paid · bought · public  | yes | yes | yes | yes |
///
/// The three things that decide it:
///
/// * **Unbought and priced** offers nothing at all — no rail, not one glyph.
///   Passing a photo on, writing it to the phone, or reacting to it are things
///   you do with a photo that is yours. There is nothing to do with this one
///   but buy it.
/// * **Like and comment are public-only.** A private photo has no audience to
///   react in front of — the thread would be the viewer talking to themselves.
///   The owner's comment switch is a narrower thing and closes the thread
///   alone: people may still like a photo nobody is allowed to discuss.
/// * **Download is the paid extra**, and only ever appears once the photo has
///   actually been bought. A free photo is free to look at and free to pass
///   on, but it is not free to keep. This is the *only* rail in the app that
///   draws it: see [FoundPhotoActions.unrestricted].
///
/// The bookmark is deliberately absent from every row. Saving a photo is
/// offered on the screens that show someone's *work* — discovery, search, a
/// profile grid, a shared link, the fullscreen viewer — where the rail is
/// [FoundPhotoActions.unrestricted]. Found you is a different surface: these
/// are photos of the viewer, gated on what they have paid for, and the
/// question there is whether to buy rather than whether to keep a reference.
///
/// None of this reaches any other page. Every entry point that is not Found
/// you builds [FoundPhotoActions.unrestricted] and is untouched by the rules
/// above.
class FoundPhotoActions {
  const FoundPhotoActions._({
    required this.like,
    required this.comment,
    required this.commentsDisabled,
    required this.save,
    required this.share,
    required this.download,
  });

  /// Every entry point that isn't Found you: like, comment, bookmark, share
  /// and send. The owner's switch closes the thread; the heart stays.
  ///
  /// **No download.** Writing the file to the phone is offered in exactly one
  /// place — Found you, on a photo the viewer has paid for — because that is
  /// the only place the app knows the photo is theirs to keep. Discovery,
  /// search, a profile grid, a shared `/p/` link and the fullscreen viewer all
  /// show someone else's work: there is no purchase behind any of it, so a
  /// download button there hands out a photographer's photo for free.
  const FoundPhotoActions.unrestricted({required bool commentsEnabled})
      : like = true,
        comment = commentsEnabled,
        commentsDisabled = !commentsEnabled,
        save = true,
        share = true,
        download = false;

  /// The Found-you rules, applied to [photo].
  factory FoundPhotoActions.forFoundPhoto(Photo photo) {
    // Free needs no transaction to be the viewer's; priced does. `isPurchased`
    // also covers a free photo already saved, but the price test alone is
    // enough to unlock and says why without needing the save to have landed.
    final unlocked = photo.price <= 0 || photo.isPurchased;
    if (!unlocked) return const FoundPhotoActions.none();

    return FoundPhotoActions._(
      // Public is the test, not the comment switch. Closing the thread is the
      // owner saying "no discussion", which is not the same as "no reactions"
      // — see [like].
      like: photo.isPublic,
      comment: photo.commentsEnabled && photo.isPublic,
      // Only where the *owner* closed the thread. A private photo shows no
      // comment glyph at all, crossed or otherwise: it has no audience by
      // rule rather than by anyone's decision, and marking every private
      // photo "comments disabled" would be noise about a thread that was
      // never on offer.
      commentsDisabled: !photo.commentsEnabled && photo.isPublic,
      // Bookmarking belongs to the screens that show someone's work, not to
      // Found you — see the class doc.
      save: false,
      share: true,
      // Unlocked and priced means bought — the free case was unlocked by the
      // other half of the test above, and free photos are never downloadable.
      download: photo.price > 0,
    );
  }

  /// A rail with nothing on it. The stage renders no rail at all rather than
  /// an empty column — see [any].
  const FoundPhotoActions.none()
      : like = false,
        comment = false,
        commentsDisabled = false,
        save = false,
        share = false,
        download = false;

  /// The heart, live.
  ///
  /// Deliberately not tied to the comment switch. Turning comments off is the
  /// owner declining a conversation — it says nothing about whether people may
  /// react, and taking the heart away with it left a photo somebody liked
  /// yesterday with no way to like it today and no explanation for either.
  final bool like;

  /// The comment glyph, live.
  final bool comment;

  /// The comment glyph drawn unavailable, in place of [comment]. Never true at
  /// the same time as it.
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
      like || comment || commentsDisabled || save || share || download;
}
