import 'package:flutter/material.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_profile_page.dart';

/// Opens a creator's profile.
///
/// Shared by every avatar and creator pin in the app — the feed's full-bleed
/// card, the older discovery card, the photo viewer's meta bar, Following —
/// so there is one place that decides where a tap on a person goes, rather
/// than each surface pushing its own route.
///
/// The page it opens is the same one the request board opens when a
/// photographer answers a request. That was the point of the consolidation:
/// the app had two profiles for one person, and a tap here reached the plainer
/// of the two.
///
/// The name and photo the caller already has are handed over as a seed, so the
/// screen opens on the person and fills in the bio, banner and rating a moment
/// later rather than showing a spinner where their face should be.
void openPhotographerProfile(
  BuildContext context, {
  required String photographerId,
  required String photographerName,
  String? photographerProfileUrl,
}) {
  if (photographerId.isEmpty) return;

  final profile = CreatorProfile.seed(
    id: photographerId,
    name: photographerName,
    photoUrl: photographerProfileUrl,
  );

  // Nothing travels with the route. The page fetches the profile from the id,
  // and its Events tab opens an album that does the same — so a profile opens
  // the same way from the feed, from Following and from the unauthenticated
  // discovery page, none of which share a bloc.
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CreatorProfilePage(profile: profile)),
  );
}
