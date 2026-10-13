import 'package:flutter/material.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/features/user_profile/presentation/pages/user_profile_page.dart';

/// Where a finished purchase takes the buyer: their gallery of paid photos.
///
/// Payment used to end by popping the Paystack page, which put the buyer back
/// on the photo they had just bought — with the Buy pill still on it, because
/// the list behind had been fetched before the payment (that half is
/// [photoIsBought]'s job now). Even with the pill gone, being returned to the
/// same photo is not an answer to "did that work?". The photos are what was
/// bought, so the photos are where to land: the Purchased grid on the profile,
/// which is newest-first (`PaidImage.createdAt desc`), so the photos from this
/// purchase are the ones at the top of it.
///
/// Three things have to happen, in this order:
///
///  1. the profile is told which tab to show, *before* it is built or
///     revealed, so the grid is never seen on Liked first;
///  2. the bottom nav is asked for the Profile tab — which also makes the
///     profile reload, since [HomePage] nudges it whenever that tab opens and
///     checkout has already bumped [GalleryRefreshSignal];
///  3. whatever was pushed over Home — the album, the viewer, the payment page
///     — is popped off, so the gallery is what the buyer is looking at.
///
/// With no Home underneath (a deep link that opened the viewer on its own, a
/// session that started at the guest feed) there is nothing to pop back to, so
/// Home is pushed instead. [HomePage.isLive] is the test rather than the route
/// stack: a second Home would discard the live one and refetch everything
/// under it.
void openPaidGallery(BuildContext context) {
  UserProfilePage.tabRequest.value = UserProfilePage.purchasedTab;
  HomePage.tabRequest.value = HomePage.profileTab;

  final navigator = Navigator.of(context);
  if (!HomePage.isLive) {
    navigator.pushNamedAndRemoveUntil(HomePage.routeName, (route) => false);
    return;
  }

  // `|| route.isFirst` is what keeps this from emptying the navigator.
  // `ModalRoute.withName` alone matches nothing when Home is not the route it
  // was pushed under, and popUntil with a predicate that never matches pops
  // every route there is, leaving a black screen.
  navigator.popUntil(
    (route) => route.settings.name == HomePage.routeName || route.isFirst,
  );
}
