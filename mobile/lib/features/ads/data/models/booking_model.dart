/// The money side of a request, as the app reads it.
///
/// A [RequestQuote] is what the chosen photographer asked for. A
/// [RequestBooking] is what has actually been paid, held and released against
/// it. They arrive together from `GET /ads/requests/{id}/quote`, and either can
/// be absent: no quote yet, or a quote sent and not yet paid.
///
/// Every "can I do this now" question is answered by the server rather than
/// worked out here. Three clients deriving `canConfirm` from raw amounts is
/// three chances to disagree about somebody's money, and the one that gets it
/// wrong shows a button that then fails.
library;

import 'package:flutter/foundation.dart';

double _toDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0.0;

int _toInt(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

DateTime? _toDate(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// One line on the quote — "Full day coverage (10 hours)  GHS 8,000".
@immutable
class QuoteLineItem {
  const QuoteLineItem({required this.label, required this.amount});

  final String label;
  final double amount;

  factory QuoteLineItem.fromJson(Map<String, dynamic> json) => QuoteLineItem(
        label: json['label'] as String? ?? '',
        amount: _toDouble(json['amount']),
      );

  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};
}

@immutable
class RequestQuote {
  const RequestQuote({
    required this.id,
    required this.requestId,
    required this.photographerId,
    required this.lineItems,
    required this.total,
    required this.currency,
    required this.status,
    this.notes,
    this.declineReason,
    this.respondedAt,
    this.createdAt,
  });

  final String id;
  final String requestId;
  final String photographerId;
  final List<QuoteLineItem> lineItems;
  final double total;
  final String currency;

  /// sent | accepted | declined | superseded. Only `sent` can be paid.
  final String status;
  final String? notes;
  final String? declineReason;
  final DateTime? respondedAt;
  final DateTime? createdAt;

  bool get isLive => status == 'sent';
  bool get isDeclined => status == 'declined';
  bool get isSuperseded => status == 'superseded';

  factory RequestQuote.fromJson(Map<String, dynamic> json) => RequestQuote(
        id: json['id'] as String? ?? '',
        requestId: json['requestId'] as String? ?? '',
        photographerId: json['photographerId'] as String? ?? '',
        lineItems: (json['lineItems'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(QuoteLineItem.fromJson)
            .toList(),
        total: _toDouble(json['total']),
        currency: json['currency'] as String? ?? 'GHS',
        status: json['status'] as String? ?? 'sent',
        notes: json['notes'] as String?,
        declineReason: json['declineReason'] as String?,
        respondedAt: _toDate(json['respondedAt']),
        createdAt: _toDate(json['createdAt']),
      );
}

@immutable
class RequestBooking {
  const RequestBooking({
    required this.id,
    required this.requestId,
    required this.quoteId,
    required this.photographerId,
    required this.requesterId,
    required this.currency,
    required this.total,
    required this.depositAmount,
    required this.amountPaid,
    required this.outstanding,
    required this.releasedAmount,
    required this.refundedAmount,
    required this.heldAmount,
    required this.platformFeePercent,
    required this.depositPercent,
    required this.status,
    required this.canPayDeposit,
    required this.canPayBalance,
    required this.canConfirm,
    required this.canDispute,
    required this.canReview,
    this.autoReleaseAt,
    this.confirmedAt,
    this.releasedAt,
    this.disputedAt,
    this.disputeReason,
    this.resolutionNote,
    this.createdAt,
  });

  final String id;
  final String requestId;
  final String quoteId;
  final String photographerId;
  final String requesterId;

  final String currency;
  final double total;

  /// Due up front to confirm the booking.
  final double depositAmount;
  final double amountPaid;

  /// Still owed. Must be zero before the job can be signed off.
  final double outstanding;

  /// Net of fee, and already in the photographer's balance.
  final double releasedAmount;
  final double refundedAmount;

  /// Paid, but neither released nor refunded — sitting in escrow.
  final double heldAmount;

  final int platformFeePercent;
  final int depositPercent;

  /// pending_deposit | deposit_paid | paid_in_full | partially_released |
  /// completed | disputed | refunded | cancelled
  final String status;

  // ── What the buttons key off ───────────────────────────────────────────
  //
  // Sent by the server rather than derived from [status] here. Adding a state
  // server-side would otherwise silently re-enable a button on a screen nobody
  // remembered to update.
  final bool canPayDeposit;
  final bool canPayBalance;
  final bool canConfirm;
  final bool canDispute;

  /// The review prompt waits for this. Offering it while the job is still in
  /// the air asks somebody to rate work that has not happened.
  final bool canReview;

  final DateTime? autoReleaseAt;
  final DateTime? confirmedAt;
  final DateTime? releasedAt;
  final DateTime? disputedAt;
  final String? disputeReason;
  final String? resolutionNote;
  final DateTime? createdAt;

  bool get isDisputed => status == 'disputed';
  bool get isRefunded => status == 'refunded';
  bool get isComplete =>
      status == 'completed' || status == 'partially_released';

  /// Money has changed hands, so the request is locked to this photographer.
  bool get isLocked => const {
        'deposit_paid',
        'paid_in_full',
        'partially_released',
        'completed',
        'disputed',
      }.contains(status);

  factory RequestBooking.fromJson(Map<String, dynamic> json) => RequestBooking(
        id: json['id'] as String? ?? '',
        requestId: json['requestId'] as String? ?? '',
        quoteId: json['quoteId'] as String? ?? '',
        photographerId: json['photographerId'] as String? ?? '',
        requesterId: json['requesterId'] as String? ?? '',
        currency: json['currency'] as String? ?? 'GHS',
        total: _toDouble(json['total']),
        depositAmount: _toDouble(json['depositAmount']),
        amountPaid: _toDouble(json['amountPaid']),
        outstanding: _toDouble(json['outstanding']),
        releasedAmount: _toDouble(json['releasedAmount']),
        refundedAmount: _toDouble(json['refundedAmount']),
        heldAmount: _toDouble(json['heldAmount']),
        platformFeePercent: _toInt(json['platformFeePercent']),
        depositPercent: _toInt(json['depositPercent']),
        status: json['status'] as String? ?? 'pending_deposit',
        canPayDeposit: json['canPayDeposit'] == true,
        canPayBalance: json['canPayBalance'] == true,
        canConfirm: json['canConfirm'] == true,
        canDispute: json['canDispute'] == true,
        canReview: json['canReview'] == true,
        autoReleaseAt: _toDate(json['autoReleaseAt']),
        confirmedAt: _toDate(json['confirmedAt']),
        releasedAt: _toDate(json['releasedAt']),
        disputedAt: _toDate(json['disputedAt']),
        disputeReason: json['disputeReason'] as String?,
        resolutionNote: json['resolutionNote'] as String?,
        createdAt: _toDate(json['createdAt']),
      );
}

/// The admin-set terms, so a screen can say "20% due now" before any booking
/// exists to read it from.
@immutable
class BookingTerms {
  const BookingTerms({
    this.depositPercent = 20,
    this.platformFeePercent = 10,
    this.releaseDays = 7,
  });

  final int depositPercent;
  final int platformFeePercent;
  final int releaseDays;

  factory BookingTerms.fromJson(Map<String, dynamic> json) => BookingTerms(
        depositPercent: _toInt(json['depositPercent']),
        platformFeePercent: _toInt(json['platformFeePercent']),
        releaseDays: _toInt(json['releaseDays']),
      );
}

/// Everything `GET /ads/requests/{id}/quote` returns, in one object.
@immutable
class BookingState {
  const BookingState({
    this.quote,
    this.booking,
    this.terms = const BookingTerms(),
    this.viewerRole = 'requester',
  });

  final RequestQuote? quote;
  final RequestBooking? booking;
  final BookingTerms terms;

  /// "requester" or "photographer" — which side of this the caller is on.
  final String viewerRole;

  bool get isRequester => viewerRole == 'requester';

  /// Nothing has happened yet: no quote, or the last one was turned down.
  bool get awaitingQuote => quote == null || !quote!.isLive;

  factory BookingState.fromJson(Map<String, dynamic> json) => BookingState(
        quote: json['quote'] is Map<String, dynamic>
            ? RequestQuote.fromJson(json['quote'] as Map<String, dynamic>)
            : null,
        booking: json['booking'] is Map<String, dynamic>
            ? RequestBooking.fromJson(json['booking'] as Map<String, dynamic>)
            : null,
        terms: json['config'] is Map<String, dynamic>
            ? BookingTerms.fromJson(json['config'] as Map<String, dynamic>)
            : const BookingTerms(),
        viewerRole: json['viewerRole'] as String? ?? 'requester',
      );
}
