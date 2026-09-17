import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_key_datasource.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_websocket_service.dart';
import 'package:jperg_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/chat/presentation/bloc/room/chat_room_bloc.dart';
import 'package:jperg_app/models/chat/chat_message.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/services/e2ee_service.dart';

/// Editing or deleting a comment has to change the list *now*.
///
/// Both were written to call the server and then re-join the room to pick the
/// change up, and re-joining cannot express either one. The join merges fresh
/// history into what it already holds and skips every id it has seen:
///
///     final incoming = fresh.where((m) => !knownIds.contains(m.id));
///     final merged   = _sorted([...state.messages, ...incoming]);
///
/// So an edited comment comes back and is discarded as a duplicate of itself,
/// and a deleted one is never removed because the merge only ever adds. That
/// is the right shape for history — a live message must never be dropped — and
/// no use at all for reflecting a change to a row already on screen. The
/// comment stayed exactly as it was until the sheet was closed and reopened.
///
/// The server was never at fault: PUT and DELETE both answer 200 and the room
/// history reflects them immediately.
class _FakeRepo implements ChatRepository {
  final updatedCache = <String, String>{};
  final deletedFromCache = <String>[];
  final cached = <ChatMessage>[];

  @override
  Future<void> updateCachedMessage(
      String messageId, String content, DateTime updatedAt) async {
    updatedCache[messageId] = content;
  }

  @override
  Future<void> deleteCachedMessage(String messageId) async {
    deletedFromCache.add(messageId);
  }

  @override
  Future<void> cacheMessage(ChatMessage message) async => cached.add(message);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not used here');
}

class _FakeAuth implements AuthService {
  @override
  Future<String> getUserId() async => 'me';
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _FakeWs implements ChatWebSocketService {
  @override
  bool get isConnected => false;
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _FakeBg implements ChatBackgroundService {
  @override
  final ChatWebSocketService sharedWs = _FakeWs();
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _FakeE2ee implements E2eeService {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

class _FakeKeys implements ChatKeyDataSource {
  @override
  dynamic noSuchMethod(Invocation i) => null;
}

ChatMessage _comment(String id, String content) => ChatMessage(
      id: id,
      roomId: 'r1',
      senderId: 'me',
      senderName: 'Ama',
      senderRole: 'user',
      content: content,
      createdAt: DateTime.utc(2026, 9, 17, 12, int.parse(id.substring(1))),
    );

void main() {
  late _FakeRepo repo;
  late ChatRoomBloc bloc;

  setUp(() {
    repo = _FakeRepo();
    bloc = ChatRoomBloc(
      getRoomMessages: GetRoomMessagesUseCase(repo),
      getRoom: GetRoomUseCase(repo),
      getCachedMessages: GetCachedMessagesUseCase(repo),
      cacheMessage: CacheMessageUseCase(repo),
      markRoomAsRead: MarkRoomAsReadUseCase(repo),
      getPresence: GetPresenceUseCase(repo),
      uploadImage: UploadChatImageUseCase(repo),
      editMessage: EditMessageUseCase(repo),
      deleteMessage: DeleteMessageUseCase(repo),
      pinMessage: PinMessageUseCase(repo),
      updateCachedMessage: UpdateCachedMessageUseCase(repo),
      deleteCachedMessage: DeleteCachedMessageUseCase(repo),
      grantAdmin: GrantAdminUseCase(repo),
      revokeAdmin: RevokeAdminUseCase(repo),
      updateRoomSettings: UpdateRoomSettingsUseCase(repo),
      setRoomMuted: SetRoomMutedUseCase(repo),
      kickParticipant: KickParticipantUseCase(repo),
      leaveRoom: LeaveRoomUseCase(repo),
      deleteRoom: DeleteRoomUseCase(repo),
      clearRoom: ClearRoomUseCase(repo),
      clearRoomCache: ClearRoomCacheUseCase(repo),
      authService: _FakeAuth(),
      bgService: _FakeBg(),
      e2eeService: _FakeE2ee(),
      keyDataSource: _FakeKeys(),
    );
    bloc.emit(ChatRoomState(
      messages: [_comment('c1', 'original'), _comment('c2', 'another')],
    ));
  });

  tearDown(() => bloc.close());

  group('editing', () {
    test('the new words are on the list at once', () async {
      bloc.add(const ChatRoomCommentEdited(
          commentId: 'c1', content: 'edited'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.messages.first.content, 'edited');
    });

    test('and written to the cache, or reopening paints the old ones back',
        () async {
      // The join emits what is stored locally before any request returns, so a
      // cache left holding the old text undoes the edit on the next open.
      bloc.add(const ChatRoomCommentEdited(
          commentId: 'c1', content: 'edited'));
      await Future<void>.delayed(Duration.zero);

      expect(repo.updatedCache['c1'], 'edited');
    });

    test('nothing else on the list moves', () async {
      bloc.add(const ChatRoomCommentEdited(
          commentId: 'c1', content: 'edited'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.messages.length, 2);
      expect(bloc.state.messages.last.content, 'another');
    });

    test('a comment not on this page is left alone', () async {
      // A reply fetched into its own list, or a row since removed.
      bloc.add(const ChatRoomCommentEdited(
          commentId: 'nope', content: 'edited'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.messages.map((m) => m.content),
          ['original', 'another']);
    });
  });

  group('deleting', () {
    test('it goes from the list at once', () async {
      bloc.add(const ChatRoomCommentRemoved('c1'));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.messages.map((m) => m.id), ['c2']);
      expect(bloc.state.messages.length, 1);
    });

    test('and from the cache', () async {
      bloc.add(const ChatRoomCommentRemoved('c1'));
      await Future<void>.delayed(Duration.zero);

      expect(repo.deletedFromCache, ['c1']);
    });

    test('a refused delete puts it back where it was', () async {
      // Dropping somebody's comment off the screen and leaving it on the
      // server is the one outcome worse than the delete failing loudly.
      final removed = bloc.state.messages.first;
      bloc.add(const ChatRoomCommentRemoved('c1'));
      await Future<void>.delayed(Duration.zero);

      bloc.add(ChatRoomCommentRestored(removed));
      await Future<void>.delayed(Duration.zero);

      // In its own place by time, not appended. The list is newest-first, and
      // c1 is the older of the two.
      expect(bloc.state.messages.map((m) => m.id), ['c2', 'c1']);
    });

    test('restoring one that is already there changes nothing', () async {
      bloc.add(ChatRoomCommentRestored(bloc.state.messages.first));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.messages.length, 2);
    });
  });
}
