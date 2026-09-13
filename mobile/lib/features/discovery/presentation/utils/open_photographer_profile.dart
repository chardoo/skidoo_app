import 'package:flutter/material.dart';
import 'package:jperg_app/core/utils/auth_guard.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_profile_page.dart';

/// Opens a creator's profile, asking a signed-out viewer to sign in first.
///
/// Shared by every avatar and creator pin in the app — the feed's full-bleed
/// card, the older discovery card, the photo viewer's meta bar, Following,
/// search, the creator suggestions, the comment threads — so there is one place
/// that decides where a tap on a person goes, rather than each surface pushing
/// its own route.
///
/// That is also why the sign-in gate lives here rather than at each tap.
/// A creator's profile is a signed-in destination: it carries their portfolio,
/// their rates and the buttons to follow and message them, none of which a
/// guest can act on. The guest feed already trades every other tap for a login
/// sheet — the album, the reactions, the more menu — and the avatar was the one
/// that went straight through, so a guest could browse creator profiles the
/// long way round while being asked to sign in for everything else on the same
/// card. Gating the helper closes that for every caller at once, including the
/// ones added after this was written.
///
/// [requireAuth] resumes the tap afterwards, so signing in lands on the profile
/// that was asked for rather than dropping the person back on the feed with
/// nothing to show for it.
///
/// The page it opens is the same one the request board opens when a
/// photographer answers a request. That was the point of the consolidation:
/// the app had two profiles for one person, and a tap here reached the plainer
/// of the two.
///
/// The name and photo the caller already has are handed over as a seed, so the
/// screen opens on the person and fills in the bio, banner and rating a moment
/// later rather than showing a spinner where their face should be.
Future<void> openPhotographerProfile(
  BuildContext context, {
  required String photographerId,
  required String photographerName,
  String? photographerProfileUrl,
}) {
  if (photographerId.isEmpty) return Future.value();

  final profile = CreatorProfile.seed(
    id: photographerId,
    name: photographerName,
    photoUrl: photographerProfileUrl,
  );

  return requireAuth(
    context,
    action: () {
      // The login sheet is an async gap, and the surface that was tapped may be
      // gone by the time it closes — a card scrolled out of the feed, or the
      // guest page replaced on the way to Home.
      if (!context.mounted) return;
      // Nothing travels with the route. The page fetches the profile from the
      // id, and its Events tab opens an album that does the same — so a profile
      // opens the same way from the feed, from Following and from search, none
      // of which share a bloc.
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CreatorProfilePage(profile: profile)),
      );
    },
  );
}
