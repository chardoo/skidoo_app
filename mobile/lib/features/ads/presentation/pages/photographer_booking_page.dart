import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
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
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/presentation/widgets/quote_composer_sheet.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/chat_error_text.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_room_page.dart';

/// A job from the photographer's side: what was asked for, what they quoted,
/// and where the money has got to.
///
/// The counterpart to ReviewPhotographersPage, which is the same request seen
/// by the person who posted it. They are separate screens rather than one with
/// branches because almost nothing is shared: the requester decides who gets
/// the job and pays for it, the photographer prices it and waits. A single
/// screen carrying both would be mostly conditionals.
///
/// Reached from the "your invitation was accepted" notification, which is the
/// moment this screen exists to serve.
class PhotographerBookingPage extends StatefulWidget {
  const PhotographerBookingPage({super.key, required this.request});

  final FeedRequestModel request;

  @override
  State<PhotographerBookingPage> createState() =>
      _PhotographerBookingPageState();
}

class _PhotographerBookingPageState extends State<PhotographerBookingPage> {
  final _repo = AdsRepository();

  BookingState? _state;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    try {
      final state = await _repo.getBookingState(widget.request.id);
      if (!mounted) return;
      setState(() {
        _state = state;
        _loading = false;
        _error = state == null ? 'Could not load this booking.' : null;
      });
    } catch (e) {
      debugPrint('[PhotographerBooking] load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load this booking.';
      });
    }
  }

  Future<void> _sendQuote() async {
    final state = _state;
    if (state == null || _busy) return;

    final result = await showModalBottomSheet<
        ({List<QuoteLineItem> items, String notes})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuoteComposerSheet(
        clientName: widget.request.requesterName.isNotEmpty
            ? widget.request.requesterName
            : 'the client',
        requestTitle: widget.request.title,
        terms: state.terms,
        // Pre-filled when revising, so changing one price does not mean
        // retyping the whole quote.
        previous: state.quote,
      ),
    );
    if (result == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await _repo.sendQuote(
        widget.request.id,
        lineItems: result.items,
        notes: result.notes,
      );
      await _load(showSpinner: false);
      if (mounted) {
        AppSnackBar.success(context, 'Quote sent. They have been notified.');
      }
    } catch (e) {
      debugPrint('[PhotographerBooking] sendQuote ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(context, _serverMessage(e, 'Could not send the quote.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _message() async {
    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: widget.request.requesterId,
        recipientRole: ChatConfig.roleClient,
        localDisplayName: widget.request.requesterName.isNotEmpty
            ? widget.request.requesterName
            : 'Client',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
    } catch (e) {
      debugPrint('[PhotographerBooking] message ERROR: $e');
      if (!mounted) return;
      AppSnackBar.error(
        context,
        chatErrorText(e, fallback: 'Could not open the conversation.'),
      );
    }
  }

  /// The server's own wording where it has some — every refusal in this flow
  /// explains itself, and replacing that with a generic failure throws away the
  /// only thing that says what to do next.
  String _serverMessage(Object error, String fallback) {
    try {
      final message = (error as dynamic).response?.data?['error']?['message'];
      if (message is String && message.isNotEmpty) return message;
    } catch (_) {
      // Not a Dio error, or shaped differently.
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final state = _state;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: kIsWeb ? null : const AppBackButton(),
        title: Text(
          'Booking',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.chat_bubble_outline_rounded,
                color: ext.greetingColor, size: 20.sp),
            tooltip: 'Message the client',
            onPressed: _message,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _load(showSpinner: false),
              color: ext.accentGold,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md.w, 0, AppSpacing.md.w, AppSpacing.xxl.h,
                ),
                children: [
                  _jobCard(ext),
                  if (_error != null) ...[
                    SizedBox(height: AppSpacing.xl.h),
                    Center(
                      child: Text(
                        _error!,
                        style: TextStyle(color: ext.searchHintColor),
                      ),
                    ),
                  ],
                  if (state != null) ...[
                    _quoteSection(state, ext),
                    if (state.booking != null) _moneySection(state, ext),
                  ],
                ],
              ),
            ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  // ── The job ─────────────────────────────────────────────────────────────

  Widget _jobCard(AppThemeExtension ext) {
    final request = widget.request;
    final date = request.eventDate;
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
          Text(
            request.title,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            [
              if (date != null) DateFormat('d MMM yyyy').format(date),
              if (request.location.isNotEmpty) request.location,
            ].join('  ·  '),
            style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
          ),
          if (request.description.isNotEmpty) ...[
            SizedBox(height: AppSpacing.md.h),
            Text(
              request.description,
              style: TextStyle(
                color: ext.searchHintColor, fontSize: 13.sp, height: 1.4,
              ),
            ),
          ],
          SizedBox(height: AppSpacing.md.h),
          Row(
            children: [
              Text(
                'Their budget',
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
              ),
              const Spacer(),
              Text(
                // Nullable: plenty of requests are posted without one, and
                // "Not specified" is a truthful answer where a blank reads as
                // a rendering fault.
                request.budgetLabel ?? 'Not specified',
                style: TextStyle(
                  color: ext.accentGold,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── The quote ───────────────────────────────────────────────────────────

  Widget _quoteSection(BookingState state, AppThemeExtension ext) {
    final quote = state.quote;
    final booking = state.booking;
    // Re-quoting is only possible while nothing has been paid. Once it has,
    // the agreed figure and the paid figure have to stay the same number.
    final canQuote = booking == null || booking.canPayDeposit;

    return Container(
      margin: EdgeInsets.only(top: AppSpacing.md.h),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.accentGold.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(color: ext.accentGold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            quote == null ? 'Send them a quote' : 'Your quote',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            _quoteBlurb(quote, booking, state.terms),
            style: TextStyle(
              color: ext.searchHintColor, fontSize: 12.sp, height: 1.4,
            ),
          ),
          if (quote != null) ...[
            SizedBox(height: AppSpacing.md.h),
            for (final item in quote.lineItems)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 2.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: ext.searchHintColor, fontSize: 13.sp,
                        ),
                      ),
                    ),
                    Text(
                      _money(item.amount, quote.currency),
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
              child: Divider(
                height: 1,
                color: ext.searchHintColor.withValues(alpha: 0.2),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  _money(quote.total, quote.currency),
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
          if (canQuote) ...[
            SizedBox(height: AppSpacing.lg.h),
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton(
                onPressed: _busy ? null : _sendQuote,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ext.accentGold,
                  disabledBackgroundColor:
                      ext.accentGold.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
                child: _busy
                    ? SizedBox(
                        height: 18.h,
                        width: 18.h,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : Text(
                        quote == null ? 'Send Quote' : 'Send a revised quote',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _quoteBlurb(
    RequestQuote? quote, RequestBooking? booking, BookingTerms terms,
  ) {
    if (quote == null) {
      return 'You were chosen for this job. Price it up and send it over — '
          'they pay ${terms.depositPercent}% to confirm the booking.';
    }
    if (quote.isDeclined) {
      return quote.declineReason?.isNotEmpty == true
          ? 'Declined: "${quote.declineReason}". You can send a revised quote.'
          : 'This quote was declined. You can send a revised one.';
    }
    if (booking == null || booking.canPayDeposit) {
      return 'Sent. Waiting for them to pay the '
          '${terms.depositPercent}% deposit.';
    }
    return 'Accepted and paid against.';
  }

  // ── The money ───────────────────────────────────────────────────────────

  Widget _moneySection(BookingState state, AppThemeExtension ext) {
    final booking = state.booking!;
    final currency = booking.currency;

    // What actually reaches them, which is not the quote total. Derived from
    // what has been released where anything has, and projected from the fee
    // rate where nothing has yet.
    final projectedNet =
        booking.total * (100 - booking.platformFeePercent) / 100;

    return Container(
      margin: EdgeInsets.only(top: AppSpacing.md.h),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        border: Border.all(
          color: ext.searchHintColor.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Payment',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          _row('Client has paid', _money(booking.amountPaid, currency), ext),
          if (booking.outstanding > 0)
            _row('Still owed by client',
                _money(booking.outstanding, currency), ext),
          if (booking.heldAmount > 0)
            _row('Held until they confirm',
                _money(booking.heldAmount, currency), ext),
          _row(
            booking.releasedAmount > 0
                ? 'In your balance'
                : 'You will receive (after ${booking.platformFeePercent}% fee)',
            _money(
              booking.releasedAmount > 0
                  ? booking.releasedAmount
                  : projectedNet,
              currency,
            ),
            ext,
            highlight: true,
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(
            _moneyBlurb(booking),
            style: TextStyle(
              color: ext.searchHintColor, fontSize: 11.sp, height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _moneyBlurb(RequestBooking booking) {
    if (booking.isDisputed) {
      return 'The client reported a problem. The payment is held while our '
          'team looks into it, and we may contact you about it.';
    }
    if (booking.isRefunded) {
      return 'This booking was cancelled and the payment returned to the '
          'client.';
    }
    if (booking.releasedAmount > 0 && booking.outstanding <= 0) {
      return 'Released. You can withdraw it from the Payouts screen.';
    }
    if (booking.releasedAmount > 0) {
      return 'Part of this has been released to you. The rest follows when '
          'the client pays the balance and confirms.';
    }
    if (booking.autoReleaseAt != null) {
      return 'The money is held until the client confirms the job is done. '
          'If they do not, it is released to you automatically on '
          '${DateFormat('d MMM yyyy').format(booking.autoReleaseAt!.toLocal())}.';
    }
    return 'The money is held until the client confirms the job is done.';
  }

  Widget _row(
    String label,
    String value,
    AppThemeExtension ext, {
    bool highlight = false,
  }) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: ext.searchHintColor, fontSize: 13.sp,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: highlight ? ext.accentGold : ext.greetingColor,
                fontSize: highlight ? 15.sp : 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

String _money(double amount, String currency) =>
    '$currency ${NumberFormat('#,##0.00').format(amount)}';
