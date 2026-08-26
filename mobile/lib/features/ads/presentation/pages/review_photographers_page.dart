import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/ads/data/models/booking_model.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/presentation/pages/ads_checkout_page.dart';
import 'package:jperg_app/features/ads/presentation/widgets/booking_panel.dart';
import 'package:jperg_app/features/ads/presentation/widgets/boost_active_bar.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/presentation/pages/my_requests_page.dart'
    show EditRequestSheet;
import 'package:jperg_app/features/ads/presentation/pages/request_photographer_page.dart';
import 'package:jperg_app/features/ads/presentation/widgets/photographer_tile.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/ads/presentation/pages/change_photographer_page.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:jperg_app/features/photographers/presentation/pages/reviews_pages.dart';

/// What happened to a request while it was open, so the list behind it knows
/// whether it is out of date.
///
/// Looking at a request changes nothing about it, and the list is expensive to
/// refetch — so "I went in and came out" has to be distinguishable from "I
/// changed something".
enum RequestOutcome { unchanged, changed, deleted }

/// The photographers who answered one request.
///
/// Split by whether the requester has opened them yet — pending is a to-do
/// list, and it shrinks as they work through it. Opening one leads to their
/// profile, and choosing happens there; the rows here carry no Message button,
/// because a conversation is something the requester starts after they have
/// picked someone. Once they have, the screen becomes that choice: "Your
/// Selection", a way to message them, and the way back out via "Change
/// photographer?".
class ReviewPhotographersPage extends StatefulWidget {
  const ReviewPhotographersPage({super.key, required this.request});

  final FeedRequestModel request;

  @override
  State<ReviewPhotographersPage> createState() =>
      _ReviewPhotographersPageState();
}

class _ReviewPhotographersPageState extends State<ReviewPhotographersPage> {
  final _repo = AdsRepository();

  late FeedRequestModel _request = widget.request;
  List<RequestInterest> _people = const [];
  bool _loading = true;
  String? _errorMessage;

  /// Anything that makes the card behind this screen wrong: a new status, a
  /// chosen photographer, an edit. Viewing does not count.
  bool _changed = false;

  /// The quote and the money against it. Null until someone has been picked
  /// and priced the job — most requests on this screen have neither.
  BookingState? _booking;

  /// A payment or confirmation is in flight. Every button in the panel goes
  /// inert: a second tap on "Pay deposit" opens a second checkout for the same
  /// money, and the two would both be charged.
  bool _bookingBusy = false;

  /// A review was left from this screen, so the prompt is withdrawn.
  ///
  /// Local to the visit rather than fetched: whether *this* person has already
  /// reviewed is not on any payload the screen loads, and one more round trip
  /// to find out would slow the common case — nobody has — to answer a
  /// question that only matters for the few seconds after writing one.
  /// Reopening the screen shows the prompt again; the server refuses the
  /// second submission, which is where the rule actually lives.
  bool _reviewed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [showSpinner] blanks the screen while it fetches — right for the first
  /// load, wrong for a refetch after an action, where wiping a list the user is
  /// looking at reads as the screen reloading itself.
  Future<void> _load({bool showSpinner = true}) async {
    setState(() {
      if (showSpinner) _loading = true;
      _errorMessage = null;
    });
    try {
      // Both at once. They are independent reads and the screen needs both
      // before it can draw anything, so running them in sequence would double
      // the wait on a connection where each already costs a round trip.
      final results = await Future.wait([
        _repo.getRequestInterests(_request.id),
        _repo.getBookingState(_request.id),
      ]);
      if (!mounted) return;
      setState(() {
        _people = results[0] as List<RequestInterest>;
        _booking = results[1] as BookingState?;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[ReviewPhotographers] load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load who answered this request.';
        _loading = false;
      });
    }
  }

  RequestInterest? get _selected {
    for (final person in _people) {
      if (person.selected) return person;
    }
    return null;
  }

  List<RequestInterest> get _pending =>
      [for (final p in _people) if (!p.viewed && !p.selected) p];

  List<RequestInterest> get _viewed =>
      [for (final p in _people) if (p.viewed && !p.selected) p];

  Future<void> _open(RequestInterest person) async {
    // Marked as looked at before the profile opens, so coming straight back
    // still moves them out of pending — the tap is the looking.
    unawaited(_markViewed(person));

    final chose = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RequestPhotographerPage(
          photographer: person,
          requestTitle: _request.title,
          alreadySelected: person.selected,
          onSelect: () => _select(person),
        ),
      ),
    );
    if (!mounted) return;

    if (chose == true) {
      // A selection reorders the whole screen — one person moves into the
      // chosen slot and everyone else's actions change with it. Worth a refetch.
      await _load(showSpinner: false);
      if (!mounted) return;
      AppSnackBar.success(context, '${person.name ?? 'Photographer'} selected.');
      return;
    }

    // Nothing happened but the looking. Move that one row from Pending to
    // Viewed in place — refetching the list to learn a single boolean is what
    // made this screen reload every time you glanced at a photographer.
    if (!person.viewed) {
      setState(() {
        _people = [
          for (final p in _people)
            p.id == person.id ? p.copyWithFlags(viewed: true) : p,
        ];
      });
    }
  }

  Future<void> _markViewed(RequestInterest person) async {
    if (person.viewed) return;
    try {
      await _repo.markInterestViewed(_request.id, person.id);
    } catch (e) {
      debugPrint('[ReviewPhotographers] markViewed ERROR: $e');
    }
  }

  Future<bool> _select(RequestInterest person) async {
    try {
      await _repo.selectPhotographer(_request.id, person.id);
      _changed = true;
      return true;
    } catch (e) {
      debugPrint('[ReviewPhotographers] select ERROR: $e');
      if (mounted) {
        AppSnackBar.error(context, 'Could not select that photographer.');
      }
      return false;
    }
  }

  Future<void> _clearSelection() async {
    try {
      await _repo.clearSelection(_request.id);
      if (!mounted) return;
      setState(() {
        _request = _request.copyWith(status: 'open');
        _changed = true;
      });
      await _load(showSpinner: false);
      if (mounted) {
        AppSnackBar.success(context, 'Request is open to photographers again.');
      }
    } catch (e) {
      debugPrint('[ReviewPhotographers] clearSelection ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not undo that.');
    }
  }

  Future<void> _message(RequestInterest person) async {
    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: person.id,
        recipientRole: ChatConfig.rolePhotographer,
        localDisplayName: person.name ?? 'Photographer',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
    } catch (e) {
      debugPrint('[ReviewPhotographers] message ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(
        context,
        chatErrorText(e, fallback: 'Could not open the conversation.'),
      );
    }
  }

  Future<void> _changePhotographer() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangePhotographerPage(
          request: _request,
          people: _people,
          currentId: _selected?.id,
        ),
      ),
    );
    if (!mounted || changed != true) return;
    _changed = true;
    await _load(showSpinner: false);
    if (mounted) AppSnackBar.success(context, 'Photographer changed successfully');
  }

  // ── The money ───────────────────────────────────────────────────────────

  /// Pay the deposit or the balance, through Paystack.
  ///
  /// The webhook is what actually credits the booking and usually lands first.
  /// The verify call after checkout closes exists because "usually" is not good
  /// enough while somebody is watching the screen; both are idempotent, so
  /// whichever arrives second applies nothing.
  Future<void> _pay({required String kind}) async {
    if (_bookingBusy) return;
    setState(() => _bookingBusy = true);
    try {
      final started = await _repo.startBookingPayment(_request.id, kind: kind);
      if (!mounted) return;

      // A previous attempt turned out to have gone through. The server applied
      // it rather than charging again, so there is no checkout to open.
      if (!started.alreadyPaid) {
        if (started.authorizationUrl.isEmpty) {
          // A zero deposit is legitimate — the server confirms the booking
          // outright and there is nothing to charge.
          if (started.booking != null) {
            await _load(showSpinner: false);
            return;
          }
          AppSnackBar.error(context, 'Could not start the payment. Try again.');
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AdsCheckoutPage(
              authorizationUrl: started.authorizationUrl,
              reference: started.reference,
              amountGhs: started.amount,
              onSuccess: () {},
            ),
          ),
        );
        if (!mounted) return;

        final verified = await _repo.verifyBookingPayment(
          _request.id, reference: started.reference,
        );
        if (!mounted) return;
        final paid = verified.booking?.amountPaid ?? 0;
        if (!verified.success || paid <= 0) {
          // Closing the WebView without paying lands here. That is the common
          // case and not an error worth alarming anybody about.
          AppSnackBar.info(
            context,
            verified.message.isNotEmpty
                ? verified.message
                : 'Payment not confirmed yet.',
          );
          await _load(showSpinner: false);
          return;
        }
      }

      _changed = true;
      await _load(showSpinner: false);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        kind == 'deposit'
            ? 'Booking confirmed. Your photographer has been notified.'
            : 'Balance paid.',
      );
    } catch (e) {
      debugPrint('[ReviewPhotographers] pay ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, _bookingError(e, 'Could not take the payment.'));
      // Reload before inviting a retry. A failure here does not mean nothing
      // happened — a payment can be confirmed server-side and still come back
      // as an error, and a stale panel would then offer to charge for it twice.
      await _load(showSpinner: false);
    } finally {
      if (mounted) setState(() => _bookingBusy = false);
    }
  }

  Future<void> _declineQuote() async {
    final reason = await _askForText(
      title: 'Decline this quote?',
      body: 'Your photographer can send a revised one. This does not change '
          'who you picked.',
      hint: 'Why? (optional)',
      confirmLabel: 'Decline',
      required: false,
    );
    if (reason == null || !mounted) return;

    setState(() => _bookingBusy = true);
    try {
      await _repo.declineQuote(_request.id, reason: reason);
      _changed = true;
      await _load(showSpinner: false);
      if (mounted) AppSnackBar.success(context, 'Quote declined.');
    } catch (e) {
      debugPrint('[ReviewPhotographers] declineQuote ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, _bookingError(e, 'Could not decline it.'));
    } finally {
      if (mounted) setState(() => _bookingBusy = false);
    }
  }

  /// "Job done" — the money goes to the photographer, and cannot come back.
  /// Confirmed twice deliberately: this is the irreversible step in the flow.
  Future<void> _confirmJobDone() async {
    final booking = _booking?.booking;
    if (booking == null) return;

    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark the job as done?'),
        content: Text(
          'This releases ${booking.currency} '
          '${booking.heldAmount.toStringAsFixed(2)} to your photographer. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Release payment'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _bookingBusy = true);
    try {
      await _repo.confirmJobDone(_request.id);
      _changed = true;
      await _load(showSpinner: false);
      if (mounted) {
        AppSnackBar.success(context, 'Payment released. Thanks!');
      }
    } catch (e) {
      debugPrint('[ReviewPhotographers] confirm ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, _bookingError(e, 'Could not confirm the job.'));
      await _load(showSpinner: false);
    } finally {
      if (mounted) setState(() => _bookingBusy = false);
    }
  }

  Future<void> _reportProblem() async {
    final reason = await _askForText(
      title: 'Report a problem',
      body: 'Tell us what went wrong. Your payment is held while our team '
          'looks into it, and your photographer is told a report was made.',
      hint: 'What happened?',
      confirmLabel: 'Report',
      required: true,
    );
    if (reason == null || reason.isEmpty || !mounted) return;

    setState(() => _bookingBusy = true);
    try {
      await _repo.reportBookingProblem(_request.id, reason: reason);
      _changed = true;
      await _load(showSpinner: false);
      if (mounted) {
        AppSnackBar.success(context, 'Reported. We will be in touch.');
      }
    } catch (e) {
      debugPrint('[ReviewPhotographers] dispute ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, _bookingError(e, 'Could not send the report.'));
    } finally {
      if (mounted) setState(() => _bookingBusy = false);
    }
  }

  /// The server's own wording where it has some.
  ///
  /// Every refusal in this flow explains itself — "GHS 10,000 is still
  /// outstanding", "this request has a paid booking" — and replacing that with
  /// a generic failure throws away the only thing that tells someone what to do
  /// next.
  String _bookingError(Object error, String fallback) {
    try {
      final response = (error as dynamic).response;
      final message = response?.data?['error']?['message'];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {
      // Not a Dio error, or shaped differently. Fall through.
    }
    return fallback;
  }

  /// A dialog with one text field. Returns null if dismissed, the text
  /// otherwise — which may be empty when [required] is false.
  Future<String?> _askForText({
    required String title,
    required String body,
    required String hint,
    required String confirmLabel,
    required bool required,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body, style: TextStyle(fontSize: 13.sp, height: 1.4)),
              SizedBox(height: AppSpacing.md.h),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: hint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              // A required reason with nothing typed leaves the button dead
              // rather than failing on the server with a validation message.
              onPressed: required && controller.text.trim().length < 5
                  ? null
                  : () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _leaveReview(RequestInterest person) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WriteReviewPage(
          photographerId: person.id,
          photographerName: person.name ?? 'Photographer',
          photographerPhotoUrl: person.profileUrl,
          photographerLocation: person.location,
          photographerFollowers: person.followerCount,
          photographerRating: person.rating,
          requestTitle: _request.title,
          requestId: _request.id,
        ),
      ),
    );
    // The rating on their row moved, so the list is stale either way.
    if (done == true && mounted) {
      // A review is once-only — the server refuses a second — so the prompt
      // goes rather than sitting there inviting something that would fail.
      setState(() => _reviewed = true);
      await _load(showSpinner: false);
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete request?'),
        content: const Text(
          'This removes the request and everyone who answered it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await _repo.deleteRequest(_request.id);
      if (mounted) Navigator.of(context).pop(RequestOutcome.deleted);
    } catch (e) {
      debugPrint('[ReviewPhotographers] delete ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not delete this request.');
    }
  }

  Future<void> _edit() async {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => EditRequestSheet(
        request: _request,
        ext: ext,
        repo: _repo,
        onSave: (updated) {
          if (mounted) {
            setState(() {
              _request = updated;
              _changed = true;
            });
          }
        },
      ),
    );
  }

  Future<void> _close() async {
    try {
      await _repo.closeRequest(_request.id, status: 'closed');
      if (!mounted) return;
      setState(() {
        _request = _request.copyWith(status: 'closed');
        _changed = true;
      });
      AppSnackBar.success(context, 'Request closed.');
    } catch (e) {
      debugPrint('[ReviewPhotographers] close ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not close this request.');
    }
  }

  Future<void> _republish() async {
    try {
      final updated = await _repo.republishRequest(_request.id);
      if (!mounted) return;
      setState(() {
        _request = updated ?? _request.copyWith(status: 'open');
        _changed = true;
      });
      AppSnackBar.success(context, 'Request is back on the board.');
    } catch (e) {
      debugPrint('[ReviewPhotographers] republish ERROR: $e');
      if (mounted) AppSnackBar.error(context, 'Could not republish this.');
    }
  }

  /// Leave, once.
  ///
  /// Two things call this and both can fire more than once for one intent: the
  /// arrow, and the deferred callback below, which is scheduled fresh for every
  /// back gesture. Two gestures inside one frame schedule two callbacks that
  /// then run back-to-back in the same post-frame batch — `mounted` is still
  /// true for the whole of the route's exit animation, so the second pop lands
  /// on the page underneath.
  ///
  /// The stack check is the same one `maybePop` makes, spelled out because
  /// `maybePop` cannot be used here: this route's [PopScope] refuses it by
  /// design, and the refusal routes straight back into this method. Popping
  /// with nothing underneath is how the app got a black screen, and this page
  /// is reachable from an `/r/` deep link, so the stack can be that shallow.
  bool _leaving = false;

  void _leave() {
    if (_leaving) return;
    final navigator = Navigator.of(context);
    if (!navigator.canPop()) return;
    _leaving = true;
    navigator.pop(
      _changed ? RequestOutcome.changed : RequestOutcome.unchanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final selected = _selected;
    // Expired counts as closed here: nobody can answer it, so editing it is
    // pointless and republishing is the only thing that helps.
    final closed = !_request.isLive;
    final booking = _booking;
    // Money has changed hands. The request is pinned to this photographer and
    // these terms until the booking settles, so everything that would move it
    // out from under the payment is withdrawn from the screen.
    final booked = booking?.booking?.isLocked ?? false;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: kIsWeb
            ? null
            : AppBackButton(onPressed: _leave),
        title: Text(
          'Request Details',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: ext.greetingColor),
            onSelected: (value) {
              if (value == 'edit') _edit();
              if (value == 'close') _close();
              if (value == 'delete') _delete();
              if (value == 'republish') _republish();
              if (value == 'unselect') _clearSelection();
            },
            // Everything that used to sit behind the card's "Manage" button
            // lives here now, since the card itself opens this screen.
            //
            // A paid booking removes most of it. Editing would rewrite terms
            // that were paid for, and closing, deleting or unpicking would
            // strand the money with no screen left to release it — the server
            // refuses all four, so offering them here would only produce
            // errors. What is left is cancelling the booking, which is a
            // support matter, not a menu item.
            itemBuilder: (_) => [
              if (!closed && !booked)
                const PopupMenuItem(
                  value: 'edit', child: Text('Edit request'),
                ),
              if (!closed && !booked)
                const PopupMenuItem(
                  value: 'close', child: Text('Close request'),
                ),
              // Only where the server would accept it — see canRepublish.
              if (_request.canRepublish && selected == null)
                const PopupMenuItem(
                  value: 'republish', child: Text('Republish request'),
                ),
              if (selected != null && !booked)
                const PopupMenuItem(
                  value: 'unselect', child: Text('Undo selection'),
                ),
              if (!booked)
                const PopupMenuItem(
                  value: 'delete', child: Text('Delete request'),
                ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              color: ext.accentGold,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md.w, 0, AppSpacing.md.w, AppSpacing.xxl.h,
                ),
                children: [
                  _RequestCard(request: _request, ext: ext),
                  if (_errorMessage != null) ...[
                    SizedBox(height: AppSpacing.xl.h),
                    Center(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: ext.searchHintColor),
                      ),
                    ),
                  ],
                  if (selected != null) ...[
                    _SectionHeader(text: 'Your Selection', ext: ext),
                    PhotographerTile(
                      person: selected,
                      ext: ext,
                      highlighted: true,
                      onTap: () => _open(selected),
                      // The whole point of choosing someone is being able to
                      // talk to them.
                      onMessage: () => _message(selected),
                    ),
                    // Hidden once money is held against this photographer.
                    // Swapping them would leave the escrow pointing at somebody
                    // no longer on the job — the server refuses it, and
                    // offering a button that fails is worse than not offering
                    // it. Cancelling the booking is the way out.
                    if (!booked)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _changePhotographer,
                          child: Text(
                            'Change photographer?',
                            style: TextStyle(
                              color: ext.searchHintColor,
                              fontSize: 12.sp,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    // The quote, what has been paid, and whatever comes next.
                    if (booking != null)
                      BookingPanel(
                        state: booking,
                        ext: ext,
                        busy: _bookingBusy,
                        onPayDeposit: () => _pay(kind: 'deposit'),
                        onPayBalance: () => _pay(kind: 'balance'),
                        onDecline: _declineQuote,
                        onConfirm: _confirmJobDone,
                        onReportProblem: _reportProblem,
                      ),
                    // Only once the job is actually done, and only once.
                    //
                    // This used to appear the moment anybody was selected,
                    // which asked people to rate work that had not happened.
                    // `canReview` is the server's answer and it waits for the
                    // payment to be released.
                    //
                    // No booking used to fall through to showing it, on the
                    // reasoning that jobs agreed outside the app still deserve
                    // a review. That is no longer true of *this* screen: the
                    // server now requires a completed booking or a photo
                    // purchase, so offering it here would open a form that
                    // 403s on submit. Somebody who bought their photos can
                    // still review from the photographer's profile, which is
                    // where that path belongs.
                    //
                    // `reviewed` hides it afterwards — a second review is
                    // refused, so leaving the prompt up promises something
                    // that cannot happen.
                    if (booking?.booking?.canReview == true && !_reviewed)
                      _ReviewPrompt(
                        name: selected.name ?? 'them',
                        ext: ext,
                        onTap: () => _leaveReview(selected),
                      ),
                    // Everyone else is deliberately not listed here. Once a
                    // choice is made this screen is about that choice; the
                    // others live behind "Change photographer?", which is the
                    // only thing you would want them for.
                  ] else ...[
                    if (_pending.isNotEmpty)
                      _SectionHeader(text: 'Pending Requests', ext: ext),
                    for (final person in _pending)
                      PhotographerTile(
                        person: person,
                        ext: ext,
                        onTap: () => _open(person),
                      ),
                    if (_viewed.isNotEmpty)
                      _SectionHeader(text: 'Viewed Requests', ext: ext),
                    for (final person in _viewed)
                      PhotographerTile(
                        person: person,
                        ext: ext,
                        onTap: () => _open(person),
                      ),
                  ],
                  if (_people.isEmpty && _errorMessage == null) ...[
                    SizedBox(height: 80.h),
                    Center(
                      child: Text(
                        'No one has answered this request yet.',
                        style: TextStyle(
                          color: ext.searchHintColor, fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );

    // The system back gesture does not go through the app bar's button, and
    // popping with nothing would tell the list "unchanged" after a selection.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Deferred: this fires from inside the navigator's own pop handling,
        // and popping again from there trips
        // `'!_debugLocked': is not true`. Waiting for the frame to end pops a
        // navigator that has settled. Reachable from an /r/ deep link, so the
        // race is not hypothetical — the link's push and a back gesture can
        // land in the same window.
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (mounted) _leave();
        });
      },
      child: webWrap(page, backgroundColor: ext.homeBackground),
    );
  }
}

/// "How was your experience?" — the way a review ever gets written.
class _ReviewPrompt extends StatelessWidget {
  const _ReviewPrompt({
    required this.name,
    required this.ext,
    required this.onTap,
  });

  final String name;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: AppSpacing.lg.h),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: ext.accentGold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How was your experience?',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Share your feedback on $name to help others in the community '
            'find great photographers.',
            style: TextStyle(
              color: ext.searchHintColor, fontSize: 13.sp, height: 1.4,
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          SizedBox(
            width: double.infinity,
            height: 44.h,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: ext.accentGold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              child: Text(
                'Leave a Review',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.ext});

  final FeedRequestModel request;
  final AppThemeExtension ext;

  String get _meta {
    final date = request.eventDate ?? request.createdAt;
    final parts = <String>[
      if (date != null)
        '${date.day.toString().padLeft(2, '0')}.'
            '${date.month.toString().padLeft(2, '0')}.${date.year}',
      if (request.location.isNotEmpty) request.location,
    ];
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final active = request.isLive;
    return Container(
      margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.title,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _meta,
                      style: TextStyle(
                        color: ext.searchHintColor, fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                active
                    ? 'Active'
                    : (request.isExpired && request.status == 'open'
                        ? 'Expired'
                        : 'Closed'),
                style: TextStyle(
                  color: active ? ext.accentGold : ext.searchHintColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // The countdown for what was paid for, inside the same card and
          // under a rule — it describes this request rather than standing
          // beside it. Only while the boost is live: a lapsed one has nothing
          // left to count, and the owner can simply buy another.
          if (request.isBoosted) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
              child: Divider(
                height: 1,
                color: ext.searchHintColor.withValues(alpha: 0.2),
              ),
            ),
            BoostActiveBar(
              daysRemaining: request.boostDaysRemaining ?? 0,
              totalDays: request.boostDays ?? 0,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text, required this.ext});

  final String text;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xs.w, AppSpacing.md.h, 0, AppSpacing.sm.h,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
}

