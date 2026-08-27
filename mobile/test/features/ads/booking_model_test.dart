/// What the app believes about a booking, and where it gets it from.
///
/// The rule these tests hold to: the app never works out for itself whether a
/// button should be there. Every `can*` comes off the wire. A client that
/// derives "the balance is settled, so Mark job done is fine" from raw amounts
/// is a client that eventually shows a button the server refuses — and the
/// person tapping it has no idea why.
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/ads/data/models/booking_model.dart';

Map<String, dynamic> _bookingJson({
  String status = 'deposit_paid',
  double total = 12500,
  double amountPaid = 2500,
  double outstanding = 10000,
  double released = 0,
  double refunded = 0,
  double held = 2500,
  bool canPayDeposit = false,
  bool canPayBalance = true,
  bool canConfirm = false,
  bool canDispute = true,
  bool canReview = false,
  bool requiresCashConfirmation = false,
  double offlineSettled = 0,
  String? autoReleaseAt,
}) =>
    {
      'id': 'book-1',
      'requestId': 'req-1',
      'quoteId': 'quote-1',
      'photographerId': 'ph-1',
      'requesterId': 'user-1',
      'currency': 'GHS',
      'total': total,
      'depositAmount': 2500,
      'amountPaid': amountPaid,
      'outstanding': outstanding,
      'releasedAmount': released,
      'refundedAmount': refunded,
      'heldAmount': held,
      'platformFeePercent': 10,
      'depositPercent': 20,
      'status': status,
      'canPayDeposit': canPayDeposit,
      'canPayBalance': canPayBalance,
      'canConfirm': canConfirm,
      'canDispute': canDispute,
      'canReview': canReview,
      'requiresCashConfirmation': requiresCashConfirmation,
      'offlineSettledAmount': offlineSettled,
      'autoReleaseAt': autoReleaseAt,
      'createdAt': '2026-08-01T10:00:00+00:00',
    };

Map<String, dynamic> _quoteJson({String status = 'sent'}) => {
      'id': 'quote-1',
      'requestId': 'req-1',
      'photographerId': 'ph-1',
      'lineItems': [
        {'label': 'Full day coverage (10 hours)', 'amount': 8000},
        {'label': 'Drone coverage (2 hours)', 'amount': 4500},
      ],
      'total': 12500,
      'currency': 'GHS',
      'notes': 'Half the balance on the day.',
      'status': status,
      'createdAt': '2026-08-01T10:00:00+00:00',
    };

void main() {
  group('RequestQuote', () {
    test('reads its line items in order', () {
      final quote = RequestQuote.fromJson(_quoteJson());
      expect(quote.lineItems, hasLength(2));
      expect(quote.lineItems.first.label, 'Full day coverage (10 hours)');
      expect(quote.lineItems.first.amount, 8000);
      expect(quote.total, 12500);
      expect(quote.notes, 'Half the balance on the day.');
    });

    test('only a sent quote is live', () {
      expect(RequestQuote.fromJson(_quoteJson()).isLive, isTrue);
      for (final status in const ['accepted', 'declined', 'superseded']) {
        expect(
          RequestQuote.fromJson(_quoteJson(status: status)).isLive,
          isFalse,
          reason: 'a $status quote must not be payable',
        );
      }
    });

    test('a missing line-item amount reads as zero, not a crash', () {
      final quote = RequestQuote.fromJson({
        ..._quoteJson(),
        'lineItems': const [
          {'label': 'Coverage'},
        ],
      });
      expect(quote.lineItems.single.amount, 0);
    });
  });

  group('RequestBooking', () {
    test('takes every action flag from the server rather than the status', () {
      // Deliberately contradictory: a status that looks confirmable with the
      // flag off. The flag wins, because the server is the one that will
      // accept or refuse the call.
      final booking = RequestBooking.fromJson(
        _bookingJson(status: 'paid_in_full', outstanding: 0, canConfirm: false),
      );
      expect(booking.canConfirm, isFalse);
    });

    test('knows when money pins the request to this photographer', () {
      for (final status in const [
        'deposit_paid',
        'paid_in_full',
        'partially_released',
        'completed',
        'disputed',
      ]) {
        expect(
          RequestBooking.fromJson(_bookingJson(status: status)).isLocked,
          isTrue,
          reason: '$status holds money and must lock the request',
        );
      }
      // Nothing has been paid, or it has all been unwound.
      for (final status in const ['pending_deposit', 'refunded', 'cancelled']) {
        expect(
          RequestBooking.fromJson(_bookingJson(status: status)).isLocked,
          isFalse,
          reason: '$status holds nothing and must not lock the request',
        );
      }
    });

    test('a disputed booking is flagged so every button can be withdrawn', () {
      final booking =
          RequestBooking.fromJson(_bookingJson(status: 'disputed'));
      expect(booking.isDisputed, isTrue);
      expect(booking.isLocked, isTrue);
    });

    test('a part-released booking still counts as complete enough to review', () {
      final booking = RequestBooking.fromJson(
        _bookingJson(status: 'partially_released', released: 2250),
      );
      expect(booking.isComplete, isTrue);
    });

    test('parses the auto-release deadline', () {
      final booking = RequestBooking.fromJson(
        _bookingJson(autoReleaseAt: '2026-09-22T00:00:00+00:00'),
      );
      expect(booking.autoReleaseAt, isNotNull);
      expect(booking.autoReleaseAt!.toUtc().year, 2026);
      expect(booking.autoReleaseAt!.toUtc().month, 9);
    });

    test('a null deadline is null rather than a fallback date', () {
      // The panel keys the "released automatically on…" line off this. A
      // fabricated date would promise a release that is not scheduled.
      expect(RequestBooking.fromJson(_bookingJson()).autoReleaseAt, isNull);
    });
  });

  group('BookingState', () {
    test('reads the quote, the booking and the terms together', () {
      final state = BookingState.fromJson({
        'quote': _quoteJson(),
        'booking': _bookingJson(),
        'viewerRole': 'requester',
        'config': const {
          'depositPercent': 20,
          'platformFeePercent': 10,
          'releaseDays': 7,
        },
      });
      expect(state.quote, isNotNull);
      expect(state.booking, isNotNull);
      expect(state.isRequester, isTrue);
      expect(state.terms.depositPercent, 20);
      expect(state.terms.releaseDays, 7);
    });

    test('survives a request nobody has quoted yet', () {
      final state = BookingState.fromJson(const {
        'quote': null,
        'booking': null,
        'viewerRole': 'photographer',
        'config': {'depositPercent': 20, 'platformFeePercent': 10,
                   'releaseDays': 7},
      });
      expect(state.quote, isNull);
      expect(state.booking, isNull);
      expect(state.awaitingQuote, isTrue);
      expect(state.isRequester, isFalse);
    });

    test('a declined quote counts as awaiting a new one', () {
      final state = BookingState.fromJson({
        'quote': _quoteJson(status: 'declined'),
        'booking': null,
        'viewerRole': 'requester',
      });
      expect(state.awaitingQuote, isTrue);
    });

    test('viewerRole is what routes a deep link to the right screen', () {
      // The "your invitation was accepted" notification goes to the
      // photographer; every other request notification goes to the requester.
      // Both carry the same link, so this flag is the whole of the decision.
      final asPhotographer = BookingState.fromJson(const {
        'viewerRole': 'photographer',
      });
      expect(asPhotographer.isRequester, isFalse);

      final asRequester =
          BookingState.fromJson(const {'viewerRole': 'requester'});
      expect(asRequester.isRequester, isTrue);
    });

    test('falls back to sane terms when the server sends no config', () {
      // An older build of the service, or a config read that failed. The
      // deposit line still has a percentage to name rather than showing "0%".
      final state = BookingState.fromJson(const {'viewerRole': 'requester'});
      expect(state.terms.depositPercent, 20);
      expect(state.terms.platformFeePercent, 10);
    });
  });

  _declineGroup();

  _cashGroup();
}

/// What a declined quote leaves behind.
///
/// Declining cancels the unpaid booking and marks the quote `declined`, so the
/// booking is gone and the quote is the only thing that still describes the
/// job. A screen reading the booking alone shows nothing at all — which is how
/// a refused quote came to look exactly like one still waiting for an answer.
void _declineGroup() {
  group('a declined quote', () {
    test('is still readable after the booking is cancelled', () {
      final state = BookingState.fromJson({
        'quote': _quoteJson(status: 'declined'),
        'booking': null,
        'viewerRole': 'photographer',
      });

      expect(state.quote, isNotNull);
      expect(state.quote!.isDeclined, isTrue);
      expect(state.booking, isNull);
    });

    test('carries the reason, which is what to revise against', () {
      final state = BookingState.fromJson({
        'quote': {..._quoteJson(status: 'declined'), 'declineReason': 'Over budget'},
        'booking': null,
        'viewerRole': 'photographer',
      });

      expect(state.quote!.declineReason, 'Over budget');
    });

    test('counts as awaiting a new quote, so the form reopens', () {
      final state = BookingState.fromJson({
        'quote': _quoteJson(status: 'declined'),
        'viewerRole': 'photographer',
      });

      expect(state.awaitingQuote, isTrue);
    });
  });

  group('reviewing', () {
    test('waits for the job to be finished', () {
      // canReview is the server's answer and it waits for the money to be
      // released — offering it earlier asks somebody to rate work that has
      // not happened.
      for (final status in const ['pending_deposit', 'deposit_paid', 'paid_in_full']) {
        final booking = RequestBooking.fromJson(
          _bookingJson(status: status, canReview: false),
        );
        expect(booking.canReview, isFalse, reason: '$status is not finished');
      }

      final done = RequestBooking.fromJson(
        _bookingJson(status: 'completed', canReview: true),
      );
      expect(done.canReview, isTrue);
    });
  });
}

/// A balance handed over in cash rather than paid through the app.
///
/// The money that matters is the money that is not there: cash never passes
/// through the platform, so it must never reach the release ledger. The app's
/// job is to ask before it settles anything, and to keep the two figures
/// visibly apart afterwards.
void _cashGroup() {
  group('settling in cash', () {
    test('Done is offered alongside Pay balance once the deposit lands', () {
      // It used to be hidden until the balance cleared, which left a job paid
      // in hand stuck open and still being chased.
      final booking = RequestBooking.fromJson(_bookingJson(
        status: 'deposit_paid',
        canPayBalance: true,
        canConfirm: true,
        requiresCashConfirmation: true,
      ));

      expect(booking.canPayBalance, isTrue);
      expect(booking.canConfirm, isTrue);
    });

    test('flags when confirming would settle a balance as cash', () {
      // This is what makes the app ask. Without it the tap would close the job
      // and write off the outstanding amount silently.
      final booking = RequestBooking.fromJson(_bookingJson(
        status: 'deposit_paid', canConfirm: true, requiresCashConfirmation: true,
      ));

      expect(booking.requiresCashConfirmation, isTrue);
      expect(booking.outstanding, greaterThan(0));
    });

    test('does not flag when the balance was paid properly', () {
      final booking = RequestBooking.fromJson(_bookingJson(
        status: 'paid_in_full',
        amountPaid: 12500,
        outstanding: 0,
        canConfirm: true,
        canPayBalance: false,
      ));

      expect(booking.requiresCashConfirmation, isFalse);
    });

    test('keeps the cash apart from what went through the app', () {
      // Two separate figures on the receipt, because only one of them is
      // money the platform can account for.
      final booking = RequestBooking.fromJson(_bookingJson(
        status: 'completed',
        amountPaid: 2500,
        outstanding: 0,
        offlineSettled: 10000,
        held: 0,
      ));

      expect(booking.amountPaid, 2500);
      expect(booking.offlineSettledAmount, 10000);
      expect(booking.heldAmount, 0, reason: 'cash is never held in escrow');
    });

    test('a cash-settled job is finished, so it can be reviewed', () {
      final booking = RequestBooking.fromJson(_bookingJson(
        status: 'completed', outstanding: 0, offlineSettled: 10000,
        canReview: true,
      ));

      expect(booking.isComplete, isTrue);
      expect(booking.canReview, isTrue);
    });

    test('reads zero for a booking with no cash against it', () {
      expect(RequestBooking.fromJson(_bookingJson()).offlineSettledAmount, 0);
    });
  });
}
