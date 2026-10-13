import 'package:flutter/material.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/features/discovery/presentation/utils/open_photographer_profile.dart';
import 'package:jperg_app/features/user_profile/presentation/utils/open_public_profile.dart';

/// Opens whoever wrote something, whichever kind of account they are.
///
/// There are two profile screens — [openPhotographerProfile] for a creator,
/// [openPublicProfile] for a person — and every surface with an author on it
/// had to know which. Comment threads are the surfaces where that went wrong,
/// because a thread is the one place the two kinds of account appear in the
/// same list:
///
///  * the photo comment sheet wired no tap at all, so from a photo's comments
///    the author's avatar was dead and a photographer's profile — with its
///    Follow and Message — simply could not be reached from there;
///  * the event comment thread opened a profile only when the author was a
///    creator, and left every other commenter untappable, which read as the
///    app having forgotten who they were.
///
/// So the rule lives here instead of at each tap: **the author's role picks
/// the screen, and everybody who is not you is tappable.** A new thread — a
/// reply list, a review, a DM — gets it by calling this.
///
/// Returns null for the viewer's own authorship, which is what a comment row
/// wants: `onUserTap` being null is how [CommentItemWidget] decides not to
/// offer the tap at all, rather than offering one that goes to your own
/// profile and shows nothing to do there.
VoidCallback? openAuthorProfileTap(
  BuildContext context, {
  required String authorId,
  required String authorName,
  required String authorRole,
  String? authorAvatarUrl,
  required bool isMe,
}) {
  if (isMe || authorId.isEmpty) return null;
  return () => openAuthorProfile(
        context,
        authorId: authorId,
        authorName: authorName,
        authorRole: authorRole,
        authorAvatarUrl: authorAvatarUrl,
      );
}

/// The navigation [openAuthorProfileTap] defers.
///
/// Both destinations gate on sign-in themselves, so a guest reading a thread
/// is asked to sign in and lands on the profile afterwards rather than having
/// the tap swallowed.
Future<void> openAuthorProfile(
  BuildContext context, {
  required String authorId,
  required String authorName,
  required String authorRole,
  String? authorAvatarUrl,
}) {
  if (authorId.isEmpty) return Future.value();

  // The role as the chat service reports it (`sender_role`, from the comment's
  // `author_role`). Anything that is not the creator role is a person: an
  // empty or unrecognised role is far likelier to be an ordinary commenter
  // than a creator, and the person screen degrades better — it carries no
  // portfolio, rates or reviews to render empty.
  if (authorRole == ChatConfig.rolePhotographer) {
    return openPhotographerProfile(
      context,
      photographerId: authorId,
      photographerName: authorName,
      photographerProfileUrl:
          (authorAvatarUrl?.isNotEmpty ?? false) ? authorAvatarUrl : null,
    );
  }

  return openPublicProfile(
    context,
    userId: authorId,
    userName: authorName,
    userProfileUrl:
        (authorAvatarUrl?.isNotEmpty ?? false) ? authorAvatarUrl : null,
  );
}
