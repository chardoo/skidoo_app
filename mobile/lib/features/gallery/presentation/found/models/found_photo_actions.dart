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
/// | free · private     | yes | yes | —   | **yes** |
/// | free · public      | yes | yes | yes | once claimed |
/// | paid · unbought    | —   | —   | —   | —     |
/// | paid · bought · private | yes | yes | —   | yes |
/// | paid · bought · public  | yes | yes | yes | yes |
///
/// Download is drawn by the bar across the bottom of the photo rather than by
/// the rail — see [anyInBar]. Everything else, sharing included, stays on the
/// rail with the other engagements. This class decides *whether* each is
/// offered; where it is drawn is the widgets' business.
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
/// * **Download needs the photo to be the viewer's to keep** — which a private
///   photo simply is, since recognition is the only thing that can reach one.
///   Otherwise it is bought, claimed or bookmarked. Found you is the only
///   surface in the app that draws it at all: see
///   [FoundPhotoActions.unrestricted].
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
    required this.isPublic,
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
  const FoundPhotoActions.unrestricted({
    required bool commentsEnabled,
    this.isPublic = true,
  })  : like = true,
        comment = commentsEnabled,
        commentsDisabled = !commentsEnabled,
        save = true,
        share = true,
        download = false;

  /// The Found-you rules, applied to [photo].
  ///
  /// [saved] is whether the viewer has bookmarked this photo, which is what
  /// earns a *free* photo its download — see [download].
  factory FoundPhotoActions.forFoundPhoto(Photo photo, {bool saved = false}) {
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
      // Is this photo the viewer's to keep?
      //
      // Three ways it can be, and the first two are the ones that were missing:
      //
      // * **Private.** A private photo is reachable only by the people
      //   recognition found in it — see the app's picture-visibility rule. So a
      //   private photo on this screen is a photo of the viewer that nobody
      //   else can even see. Free and private together leaves nothing to
      //   transact: no price to pay and no audience to withhold it from.
      //   Requiring a save first was a step that granted nothing, and Found you
      //   does not offer the bookmark that would have completed it (see [save])
      //   — so the button could not be earned from the screen it was missing
      //   from.
      //
      // * **Acquired.** [Photo.isPurchased] is a `PaidImage` row, and a *free*
      //   photo added to the gallery writes one too, at a price of zero — the
      //   endpoint's own words are "free is still a claim on the photo". This
      //   rule used to ask `price > 0` instead, which is true only of paid
      //   photos, so a free photo the viewer had explicitly claimed came out
      //   the same as one they had never touched.
      //
      // * **Bookmarked**, which is the [SavedItem] collection and a different
      //   thing again. Kept because it is a real claim, though after the two
      //   above it only ever decides a free *public* photo.
      //
      // What is still refused: a free public photo nobody has claimed. It is
      // there to be looked at, and taking the file is the thing a claim is for.
      // A priced photo cannot reach here unbought at all — the gate above
      // turned it away.
      download: !photo.isPublic || photo.isPurchased || saved,
      isPublic: photo.isPublic,
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
        download = false,
        // Nothing is offered, so nothing is placed. True rather than false
        // only because [engagementsAtBottom] would otherwise claim a bottom
        // row for a photo with no actions at all.
        isPublic = true;

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

  /// Whether anyone but the viewer can see this photo. Decides *where* the
  /// engagements are drawn rather than which of them exist — see
  /// [engagementsAtBottom].
  final bool isPublic;

  bool get any =>
      like || comment || commentsDisabled || save || share || download;

  /// Every engagement, wherever it ends up being drawn: the heart, the thread,
  /// the bookmark and passing the photo on. Not the download, which is not an
  /// engagement — see [download].
  bool get anyEngagement =>
      like || comment || commentsDisabled || save || share;

  /// Whether the engagements belong in the bottom bar instead of the rail.
  ///
  /// **A private photo with no reactions on it.** Both halves matter:
  ///
  /// * Private, because that is the case this exists for — in Found you a
  ///   private photo can be neither liked nor discussed (see [like]), so its
  ///   rail comes down to passing the photo on. A vertical rail holding one
  ///   glyph is a column only in name, and it costs the right-hand edge of a
  ///   photograph to draw.
  /// * And no reactions, because that is *why* it is worth moving. A private
  ///   photo on a screen that shows someone's work still has the full set —
  ///   heart, thread, bookmark, share, each with a count — and four counted
  ///   actions laid beside the photographer's name is not a bar, it is an
  ///   overflowing row. Those keep the rail.
  ///
  /// So this is not "private photos move"; it is "a rail with nothing to react
  /// with is not a rail". Public photos are untouched either way.
  bool get engagementsAtBottom =>
      !isPublic && !like && !comment && !commentsDisabled;

  /// What the vertical rail down the right edge draws.
  ///
  /// Empty for a private photo, whose engagements moved to the bar.
  bool get anyInRail => anyEngagement && !engagementsAtBottom;

  /// What the bottom bar draws, beside the photographer's name.
  ///
  /// The download always — it is the one action that takes the file off the
  /// platform, and it sits next to the name of whoever took it. Plus the
  /// engagements, on a private photo that has any.
  bool get anyInBar => download || (anyEngagement && engagementsAtBottom);
}
