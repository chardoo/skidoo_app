import 'package:flutter/material.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/auth/presentation/pages/face_capture_step_page.dart';
import 'package:skidoo_app/features/auth/presentation/pages/login_page.dart';
import 'package:skidoo_app/features/auth/presentation/pages/signup_page.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// Whether the current user can see Found results, and if not, why.
///
/// Found matches photos against a reference selfie, so it needs both an
/// account and a face on file. The two failure modes look the same to the user
/// — an empty Found tab — but resolve differently, which is why they are
/// distinguished here rather than lumped into one "not available" state.
enum FoundAccess {
  /// Account and face both present — render the real feed.
  ready,

  /// No account. Needs sign-up (then face capture).
  signedOut,

  /// Signed in, but no reference selfie uploaded. Needs face capture only.
  noFaceAdded,
}

/// Resolves the gate for the current user.
///
/// Reads through [AuthService] rather than taking the values as arguments so
/// every call site agrees on what "can use Found" means; callers re-run it
/// after auth or face capture to pick up the change.
Future<FoundAccess> resolveFoundAccess() async {
  final auth = sl<AuthService>();
  final token = await auth.getToken();
  if (token.isEmpty) return FoundAccess.signedOut;
  return await auth.getHasAddedFaces()
      ? FoundAccess.ready
      : FoundAccess.noFaceAdded;
}

/// Headline shown when sign-up is *prompted* by a gated action, per the guest
/// designs. Deliberately shared by the Found gate and the engagement gate so
/// both explain themselves the same way.
const kJoinPromptHeadline = 'Join to get the full experience';
const kJoinPromptSubheadline = "Let's get you started";

/// Sends a guest to sign-up, and on success runs [onAuthenticated].
///
/// The callback is what makes the gate feel like a detour rather than a dead
/// end: the tap that triggered it (a like, a follow, "Add my face") is
/// replayed once the account exists, instead of the user being returned to the
/// feed having lost what they were doing.
Future<void> promptSignUp(
  BuildContext context, {
  VoidCallback? onAuthenticated,
}) async {
  final navigator = Navigator.of(context);

  await navigator.push<void>(
    MaterialPageRoute(
      builder: (routeContext) => SignUpPage(
        headline: kJoinPromptHeadline,
        subheadline: kJoinPromptSubheadline,
        onContinueBrowsing: () => Navigator.of(routeContext).pop(),
      ),
    ),
  );

  // Sign-up runs through email verification and can land the user anywhere in
  // that wizard, so trust the auth state on return rather than the route's
  // result.
  if ((await sl<AuthService>().getToken()).isNotEmpty) {
    onAuthenticated?.call();
  }
}

/// Opens the existing face-capture step.
Future<void> startFaceCapture(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => const FaceCaptureStepPage()),
  );
}

/// "Already have an account? Sign in" — from the signed-out Found gate.
Future<void> openSignIn(
  BuildContext context, {
  VoidCallback? onAuthenticated,
}) async {
  await Navigator.of(context).pushNamed(LoginPage.routeName);
  if (!context.mounted) return;
  if ((await sl<AuthService>().getToken()).isNotEmpty) {
    onAuthenticated?.call();
  }
}

/// Gate for engagement actions (like, comment, bookmark, share, follow) in
/// guest mode: signed-in users act immediately, guests are routed to sign-up
/// and the action is replayed afterwards.
///
/// This is the sign-up counterpart to `requireAuth`, which opens a *login*
/// sheet. The guest designs call for create-account here, since these taps
/// come from people who most likely have no account yet.
Future<void> requireAccount(
  BuildContext context, {
  required VoidCallback action,
}) async {
  if ((await sl<AuthService>().getToken()).isNotEmpty) {
    action();
    return;
  }
  if (!context.mounted) return;
  await promptSignUp(context, onAuthenticated: action);
}
