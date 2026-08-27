import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/models/booking_model.dart';

/// The quote, what it costs, and whatever the requester can do about it next.
///
/// One panel for the whole money flow rather than a screen per step. Paying a
/// deposit, paying the balance and signing the job off are three moments in one
/// arrangement, and splitting them across screens loses the thing somebody
/// actually wants to see: what was agreed, what is paid, what is left.
///
/// Which button appears is decided by the server, through the `can*` flags on
/// [RequestBooking] — never inferred from the status here. A client working out
/// for itself whether the balance is settled is a client that eventually shows
/// "Mark job done" on a booking the server will refuse.
class BookingPanel extends StatelessWidget {
  const BookingPanel({
    super.key,
    required this.state,
    required this.ext,
    required this.onPayDeposit,
    required this.onPayBalance,
    required this.onDecline,
    required this.onConfirm,
    required this.onReportProblem,
    this.busy = false,
  });

  final BookingState state;
  final AppThemeExtension ext;
  final VoidCallback onPayDeposit;
  final VoidCallback onPayBalance;
  final VoidCallback onDecline;
  final VoidCallback onConfirm;
  final VoidCallback onReportProblem;

  /// A payment or confirmation is in flight. Every button goes inert — a second
  /// tap on "Pay deposit" is a second checkout for the same money.
  final bool busy;

  RequestQuote? get _quote => state.quote;
  RequestBooking? get _booking => state.booking;

  @override
  Widget build(BuildContext context) {
    final quote = _quote;
    final booking = _booking;

    // Nothing priced yet. Said out loud rather than left blank: a requester who
    // has picked somebody and sees an empty screen assumes it is broken.
    if (quote == null) {
      return _Card(
        ext: ext,
        child: _Muted(
          ext: ext,
          title: 'Waiting on a quote',
          body: 'Your photographer will send a price for the job. '
              "You'll be notified when it arrives.",
        ),
      );
    }

    // Turned down, and nothing has replaced it yet.
    if (quote.isDeclined && booking == null) {
      return _Card(
        ext: ext,
        child: _Muted(
          ext: ext,
          title: 'Quote declined',
          body: quote.declineReason?.isNotEmpty == true
              ? 'You said: "${quote.declineReason}". '
                  'Your photographer can send a revised quote.'
              : 'Your photographer can send a revised quote.',
        ),
      );
    }

    return _Card(
      ext: ext,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(quote, booking),
          SizedBox(height: AppSpacing.md.h),
          ...quote.lineItems.map((item) => _line(item.label,
              _money(item.amount, quote.currency), bold: false)),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
            child: Divider(
              height: 1,
              color: ext.searchHintColor.withValues(alpha: 0.2),
            ),
          ),
          _line('Total', _money(quote.total, quote.currency), bold: true),
          if (quote.notes?.isNotEmpty == true) ...[
            SizedBox(height: AppSpacing.md.h),
            Text(
              quote.notes!,
              style: TextStyle(
                color: ext.searchHintColor, fontSize: 12.sp, height: 1.4,
              ),
            ),
          ],
          if (booking != null) ...[
            SizedBox(height: AppSpacing.md.h),
            _progress(booking),
          ],
          SizedBox(height: AppSpacing.lg.h),
          ..._actions(quote, booking),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────

  Widget _header(RequestQuote quote, RequestBooking? booking) {
    final (label, colour) = _statusChip(booking);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Your quote',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999.r),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: colour, fontSize: 11.sp, fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  (String, Color) _statusChip(RequestBooking? booking) {
    if (booking == null) return ('Awaiting payment', ext.accentGold);
    switch (booking.status) {
      case 'pending_deposit':
        return ('Awaiting deposit', ext.accentGold);
      case 'deposit_paid':
        return ('Deposit paid', ext.infoBlue);
      case 'paid_in_full':
        return ('Paid in full', ext.infoBlue);
      case 'partially_released':
        return ('Balance owing', ext.accentGold);
      case 'completed':
        return ('Completed', const Color(0xFF10B981));
      case 'disputed':
        return ('Under review', const Color(0xFFEF4444));
      case 'refunded':
        return ('Refunded', ext.searchHintColor);
      case 'cancelled':
        return ('Cancelled', ext.searchHintColor);
      default:
        return (booking.status, ext.searchHintColor);
    }
  }

  // ── What has been paid ─────────────────────────────────────────────────

  Widget _progress(RequestBooking booking) {
    final currency = booking.currency;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.circular(AppRadius.md.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _line('Paid in the app', _money(booking.amountPaid, currency),
              bold: false),
          // Named as its own line rather than folded into "paid". It is the
          // one figure here the platform cannot vouch for — the two of them
          // settled it between themselves — and a receipt that blurs that is
          // claiming more than it knows.
          if (booking.offlineSettledAmount > 0)
            _line('Paid directly, in cash',
                _money(booking.offlineSettledAmount, currency), bold: false),
          if (booking.outstanding > 0)
            _line('Still to pay', _money(booking.outstanding, currency),
                bold: true, highlight: true),
          if (booking.releasedAmount > 0)
            _line('Released to photographer',
                _money(booking.releasedAmount, currency), bold: false),
          if (booking.refundedAmount > 0)
            _line('Refunded to you', _money(booking.refundedAmount, currency),
                bold: false),
          // What happens if nobody does anything. Stated plainly, because
          // money moving on a timer that was never mentioned is the kind of
          // surprise that turns into a complaint.
          if (booking.heldAmount > 0 && booking.autoReleaseAt != null) ...[
            SizedBox(height: AppSpacing.sm.h),
            Text(
              '${_money(booking.heldAmount, currency)} is held until you '
              'confirm the job is done. If you do not, it is released to your '
              'photographer on ${DateFormat('d MMM yyyy').format(booking.autoReleaseAt!.toLocal())}.',
              style: TextStyle(
                color: ext.searchHintColor, fontSize: 11.sp, height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────

  List<Widget> _actions(RequestQuote quote, RequestBooking? booking) {
    // Being looked at by an admin. No buttons at all — every one of them would
    // move money that is deliberately frozen.
    if (booking != null && booking.isDisputed) {
      return [
        _Muted(
          ext: ext,
          title: 'We are looking into this',
          body: 'Your report is with our team. The payment is held until it '
              'is resolved, and we may contact you about it.',
        ),
      ];
    }

    if (booking != null && booking.isRefunded) {
      return [
        _Muted(
          ext: ext,
          title: 'Refunded',
          body: booking.resolutionNote?.isNotEmpty == true
              ? booking.resolutionNote!
              : 'This booking was cancelled and your payment returned.',
        ),
      ];
    }

    final canPayDeposit = booking?.canPayDeposit ?? quote.isLive;
    final deposit = booking?.depositAmount ??
        quote.total * state.terms.depositPercent / 100;

    return [
      if (canPayDeposit) ...[
        _primary(
          label: 'Pay ${_money(deposit, quote.currency)} deposit',
          onTap: onPayDeposit,
        ),
        SizedBox(height: AppSpacing.sm.h),
        Text(
          '${state.terms.depositPercent}% now to confirm the booking. '
          'The rest is due before you sign the job off.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ext.searchHintColor, fontSize: 11.sp, height: 1.4,
          ),
        ),
        SizedBox(height: AppSpacing.sm.h),
        _secondary(label: 'Decline this quote', onTap: onDecline),
      ],
      // Paying the balance is the primary route, so it keeps the filled
      // button; confirming sits under it as the alternative.
      if (booking?.canPayBalance == true) ...[
        _primary(
          label: 'Pay ${_money(booking!.outstanding, booking.currency)} balance',
          onTap: onPayBalance,
        ),
        SizedBox(height: AppSpacing.sm.h),
      ],
      if (booking?.canConfirm == true) ...[
        // Both appear together once the deposit lands. Plenty of balances are
        // handed over on the day rather than paid online, and hiding this
        // until the balance cleared left those jobs stuck open — still being
        // chased for money that had already changed hands.
        if (booking!.canPayBalance)
          _outlined(label: 'Mark job as done', onTap: onConfirm)
        else
          _primary(label: 'Mark job as done', onTap: onConfirm),
        SizedBox(height: AppSpacing.sm.h),
        Text(
          booking.requiresCashConfirmation
              // Says outright what confirming now would mean, before the
              // dialog asks it properly. Somebody who has not paid the balance
              // should not reach that dialog by surprise.
              ? 'Only mark this done once you have what you agreed. If you '
                  'paid the remaining ${_money(booking.outstanding, booking.currency)} '
                  'directly, we will ask you to confirm that.'
              : 'This releases the payment to your photographer. Only do this '
                  'once you have what you agreed.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ext.searchHintColor, fontSize: 11.sp, height: 1.4,
          ),
        ),
      ],
      if (booking?.canDispute == true) ...[
        SizedBox(height: AppSpacing.sm.h),
        _secondary(
          label: 'Report a problem',
          onTap: onReportProblem,
          danger: true,
        ),
      ],
      if (booking?.isComplete == true)
        _Muted(
          ext: ext,
          title: 'All done',
          body: 'The payment has been released to your photographer.'
              '${booking!.outstanding > 0 ? ' A balance of ${_money(booking.outstanding, booking.currency)} is still outstanding.' : ''}',
        ),
    ];
  }

  Widget _primary({required String label, required VoidCallback onTap}) =>
      SizedBox(
        width: double.infinity,
        height: 46.h,
        child: ElevatedButton(
          onPressed: busy ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: ext.accentGold,
            disabledBackgroundColor: ext.accentGold.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999.r),
            ),
          ),
          child: busy
              ? SizedBox(
                  height: 18.h,
                  width: 18.h,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      );

  /// An outlined button, for an action offered beside a filled one.
  ///
  /// "Mark job as done" is a real choice rather than a fallback, so it stays a
  /// button — but it must not compete with "Pay balance" when both are up.
  Widget _outlined({required String label, required VoidCallback onTap}) =>
      SizedBox(
        width: double.infinity,
        height: 46.h,
        child: OutlinedButton(
          onPressed: busy ? null : onTap,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: ext.accentGold.withValues(alpha: 0.6)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999.r),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: ext.accentGold,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );

  Widget _secondary({
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final colour = danger ? const Color(0xFFEF4444) : ext.searchHintColor;
    return SizedBox(
      width: double.infinity,
      height: 42.h,
      child: TextButton(
        onPressed: busy ? null : onTap,
        child: Text(
          label,
          style: TextStyle(
            color: colour, fontSize: 13.sp, fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ── Bits ───────────────────────────────────────────────────────────────

  Widget _line(
    String label,
    String value, {
    required bool bold,
    bool highlight = false,
  }) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: bold ? ext.greetingColor : ext.searchHintColor,
                  fontSize: bold ? 14.sp : 13.sp,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            SizedBox(width: AppSpacing.sm.w),
            Text(
              value,
              style: TextStyle(
                color: highlight
                    ? ext.accentGold
                    : (bold ? ext.greetingColor : ext.searchHintColor),
                fontSize: bold ? 14.sp : 13.sp,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

/// Money somebody is about to be charged. Thousands separated and always two
/// decimals — "GHS 12500.0" on a payment button is how a figure gets misread.
String _money(double amount, String currency) =>
    '$currency ${NumberFormat('#,##0.00').format(amount)}';

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.ext});

  final Widget child;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) => Container(
        margin: EdgeInsets.only(top: AppSpacing.lg.h),
        padding: EdgeInsets.all(AppSpacing.lg.w),
        decoration: BoxDecoration(
          color: ext.accentGold.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadius.lg.r),
          border: Border.all(color: ext.accentGold.withValues(alpha: 0.3)),
        ),
        child: child,
      );
}

class _Muted extends StatelessWidget {
  const _Muted({required this.ext, required this.title, required this.body});

  final AppThemeExtension ext;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            body,
            style: TextStyle(
              color: ext.searchHintColor, fontSize: 12.sp, height: 1.4,
            ),
          ),
        ],
      );
}
