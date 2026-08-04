import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/feed_item_card.dart';
import 'package:skidoo_app/features/chat/presentation/chat_error_text.dart';

FeedRequestModel _request({
  bool viewerInterested = false,
  String? viewerMessage,
  int interestedCount = 0,
}) =>
    FeedRequestModel.fromJson({
      'id': 'req-1',
      'title': 'Wedding in Accra',
      'description': 'Two days, outdoor',
      'event_type': 'Wedding',
      'location': 'Accra',
      'requester_id': 'user-1',
      'requester_name': 'Ama',
      'requester_type': 'client',
      'status': 'open',
      'interested_count': interestedCount,
      'viewer_interested': viewerInterested,
      'viewer_message': viewerMessage,
      'createdAt': '2026-08-01T10:00:00+00:00',
      'updatedAt': '2026-08-01T10:00:00+00:00',
    });

void main() {
  group('a request card offers one action, and it is not a DM', () {
    test('the CTA answers the request rather than opening a conversation', () {
      var answered = 0;
      final data = FeedItemData.fromRequest(
        _request(),
        onAnswerTap: () => answered++,
      );

      expect(data.ctaLabel, 'Message Requester');
      expect(data.ctaUrl, isNull, reason: 'nothing to launch — it posts');
      data.onCtaTap!();
      expect(answered, 1);
    });

    test('once answered the label says so', () {
      final data = FeedItemData.fromRequest(
        _request(viewerInterested: true),
        onAnswerTap: () {},
      );
      expect(data.ctaLabel, 'Invitation sent');
    });

    test('your own request has no action at all', () {
      // The board passes null for a request you posted. Nothing to tap, and
      // in particular nothing that could try to DM you about your own post —
      // which is the 400 that used to read as "not accepting messages".
      final data = FeedItemData.fromRequest(_request(), onAnswerTap: null);
      expect(data.onCtaTap, isNull);
    });
  });

  group('the note survives the round trip', () {
    test('viewer_message is read, so answering again is an edit', () {
      final req = _request(
        viewerInterested: true,
        viewerMessage: 'I shoot two-day weddings',
      );
      expect(req.viewerMessage, 'I shoot two-day weddings');
    });

    test('an unanswered request has no note', () {
      expect(_request().viewerMessage, isNull);
    });

    test('copyWith carries it, so the card updates without a reload', () {
      final updated = _request().copyWith(
        viewerInterested: true,
        viewerMessage: 'Available that weekend',
        interestedCount: 3,
      );
      expect(updated.viewerInterested, isTrue);
      expect(updated.viewerMessage, 'Available that weekend');
      expect(updated.interestedCount, 3);
    });
  });

  group('chat errors say what the server said', () {
    test('the not-accepting case is a 403, and is named as such', () {
      final text = chatErrorText(
        const ApiException(
          'Chat API error 403: {...}',
          statusCode: 403,
          code: 'RECIPIENT_NOT_ACCEPTING_DMS',
        ),
        fallback: 'Could not open chat.',
      );
      expect(text, 'This user is not accepting new conversations.');
    });

    test('a blocked pair is distinct from a closed inbox', () {
      final text = chatErrorText(
        const ApiException('Chat API error 403: {...}',
            statusCode: 403, code: 'USER_BLOCKED'),
        fallback: 'Could not open chat.',
      );
      expect(text, 'You cannot message this user.');
    });

    test('a 400 is NOT "not accepting messages"', () {
      // The old check searched the message for "400" and turned "you cannot
      // start a DM with yourself" into a claim about the other person's
      // settings. It reported the one thing that was definitely not wrong.
      final text = chatErrorText(
        const ApiException(
          'Chat API error 400: {"error":{"code":"BAD_REQUEST",'
          '"message":"You cannot start a DM with yourself"}}',
          statusCode: 400,
          code: 'BAD_REQUEST',
        ),
        fallback: 'Could not open chat.',
      );
      expect(text, 'Could not open chat.');
    });

    test('a body that merely contains 400 does not trigger it either', () {
      final text = chatErrorText(
        const ApiException('Chat API error 500: {"detail":"row 400 failed"}',
            statusCode: 500),
        fallback: 'Could not open chat.',
      );
      expect(text, 'Could not open chat.');
    });

    test('no connection reads as no connection', () {
      expect(
        chatErrorText(const NetworkException(), fallback: 'x'),
        'No connection. Try again.',
      );
    });
  });
}
