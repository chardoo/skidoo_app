import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart';

void main() {
  group('CanMessageResult.fromJson', () {
    test('parses an allowed response', () {
      final r = CanMessageResult.fromJson({
        'can_message': true,
        'reason': null,
        'has_existing_conversation': true,
      });
      expect(r.canMessage, isTrue);
      expect(r.reason, isNull);
      expect(r.hasExistingConversation, isTrue);
      expect(r.notAcceptingDms, isFalse);
    });

    test('parses a not-accepting-DMs response', () {
      final r = CanMessageResult.fromJson({
        'can_message': false,
        'reason': 'RECIPIENT_NOT_ACCEPTING_DMS',
        'has_existing_conversation': false,
      });
      expect(r.canMessage, isFalse);
      expect(r.notAcceptingDms, isTrue);
    });

    test('blocked / self are not treated as not-accepting', () {
      expect(
        CanMessageResult.fromJson({'can_message': false, 'reason': 'USER_BLOCKED'})
            .notAcceptingDms,
        isFalse,
      );
      expect(
        CanMessageResult.fromJson({'can_message': false, 'reason': 'SELF'})
            .notAcceptingDms,
        isFalse,
      );
    });

    test('defaults are permissive on missing fields', () {
      final r = CanMessageResult.fromJson({});
      expect(r.canMessage, isTrue);
      expect(r.reason, isNull);
      expect(r.hasExistingConversation, isFalse);
    });

    test('allowed() factory is permissive', () {
      expect(CanMessageResult.allowed().canMessage, isTrue);
    });
  });
}
