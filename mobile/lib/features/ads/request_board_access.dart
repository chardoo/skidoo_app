import 'package:jperg_app/services/auth_service.dart';

/// Who may *browse* the request board.
///
/// One rule, in one place, because the same question is asked from three
/// unrelated screens and the answer drifted between them.
///
/// A request is a job going begging. It means nothing to somebody who cannot
/// do the work, so `GET /ads/requests` serves photographers and admins and
/// answers everyone else with an empty list — deliberately empty rather than a
/// 403, because the app asks before it knows who is looking and an error
/// renders as a broken screen.
///
/// That server rule was right and the app never matched it. The board was
/// offered to everybody, gated only on the `requestsEnabled` config flag, so an
/// ordinary account saw "Request Board — browse open requests from others",
/// tapped it, and arrived at a screen that was empty and always would be. The
/// emptiness looked like a loading failure, which is the worst reading of it:
/// nothing was broken, they were simply never the audience.
///
/// Three things this is deliberately *not*:
///
/// - **Not a gate on posting.** Anyone may post a request — that is the whole
///   point of the board, and clients are who most requests come from. `Create`
///   stays offered to everyone.
/// - **Not a gate on your own requests.** A requester finds what they posted
///   through `/requests/mine`, which is theirs whatever their role. `My
///   Requests` stays offered to everyone.
/// - **Not a gate on campaigns.** An ad campaign is something any account can
///   buy and any account can already see running in the feed. `My Campaigns`
///   is keyed on `adsEnabled` alone and must stay that way; folding it in here
///   is the mistake this file exists to make hard.
///
/// Watch [AuthService.role] rather than calling this once at build time.
/// Upgrading to a creator changes the role mid-session, from a wizard several
/// routes deep, and a screen that read the answer once keeps the stale one
/// until the next sign-in.
bool canBrowseRequestBoard(String role) =>
    role == 'photographer' || _adminRoles.contains(role);

/// Admins see the board so they can moderate it.
///
/// Both spellings: the backend's `ADMIN_ROLES` and the string this app stores.
/// They have never quite agreed — [AuthService.isSuperAdmin] compares against
/// `super_admin` while the API issues `superAdmin` — and a board that silently
/// fails to open for an admin is not worth the tidiness of picking one here.
const _adminRoles = {'super_admin', 'superAdmin', 'Admin', 'admin'};
