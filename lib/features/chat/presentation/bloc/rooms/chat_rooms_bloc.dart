import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/features/chat/data/datasources/chat_background_service.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/models/chat/chat_message.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';

part 'chat_rooms_event.dart';
part 'chat_rooms_state.dart';

class ChatRoomsBloc extends Bloc<ChatRoomsEvent, ChatRoomsState> {
  final GetMyRoomsUseCase _getMyRooms;
  final GetCachedRoomsUseCase _getCachedRooms;
  final GetUnreadCountsUseCase _getUnreadCounts;
  final GetRoomMessagesUseCase _getRoomMessages;
  final ChatBackgroundService _bgService;

  ChatRoomsBloc({
    required GetMyRoomsUseCase getMyRooms,
    required GetCachedRoomsUseCase getCachedRooms,
    required GetUnreadCountsUseCase getUnreadCounts,
    required GetRoomMessagesUseCase getRoomMessages,
    required ChatBackgroundService bgService,
  })  : _getMyRooms = getMyRooms,
        _getCachedRooms = getCachedRooms,
        _getUnreadCounts = getUnreadCounts,
        _getRoomMessages = getRoomMessages,
        _bgService = bgService,
        super(const ChatRoomsState()) {
    on<ChatRoomsLoadRequested>(_onLoad);
    on<ChatRoomsRefreshUnread>(_onRefreshUnread);

    // Wire background service → bloc so new background messages update the badge.
    _bgService.onUnreadUpdate = () {
      if (!isClosed) add(const ChatRoomsRefreshUnread());
    };
  }

  Future<void> _onLoad(
    ChatRoomsLoadRequested event,
    Emitter<ChatRoomsState> emit,
  ) async {
    // 1. Load cache + unread counts instantly.
    try {
      final results = await Future.wait([
        _getCachedRooms(),
        _getUnreadCounts(),
      ]);
      final cached = results[0] as List<ChatRoom>;
      final counts = results[1] as Map<String, int>;
      if (cached.isNotEmpty) {
        emit(state.copyWith(
          rooms: cached,
          unreadCounts: counts,
          isSyncing: true,
          clearError: true,
        ));
      } else {
        emit(state.copyWith(isLoading: true, isSyncing: true, clearError: true));
      }
    } catch (_) {
      emit(state.copyWith(isLoading: true, isSyncing: true, clearError: true));
    }

    // 2. Sync from server then refresh counts.
    try {
      final fresh = await _getMyRooms();
      final counts = await _getUnreadCounts();
      emit(state.copyWith(
        rooms: fresh,
        unreadCounts: counts,
        isLoading: false,
        isSyncing: false,
        clearError: true,
      ));

      // 3. Background-fetch the latest messages for every room so the local
      //    DB is populated and unread counts reflect actual new messages.
      //    Errors are silently ignored — this is best-effort.
      _syncMessagesInBackground(fresh);

      // 4. Ensure background WebSocket connections are active for all rooms.
      _bgService.connectAll(fresh);
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        isSyncing: false,
        errorMessage: state.rooms.isEmpty ? 'Could not load chats.' : null,
      ));
    }
  }

  /// Fetches the first page of messages for each room without marking them
  /// as read, then refreshes unread counts so the navbar badge updates.
  Future<void> _syncMessagesInBackground(List<ChatRoom> rooms) async {
    try {
      await Future.wait(
        rooms.map((room) => _getRoomMessages(room.id).catchError((_) => <ChatMessage>[])),
      );
      if (!isClosed) add(const ChatRoomsRefreshUnread());
    } catch (_) {}
  }

  Future<void> _onRefreshUnread(
    ChatRoomsRefreshUnread event,
    Emitter<ChatRoomsState> emit,
  ) async {
    try {
      final counts = await _getUnreadCounts();
      emit(state.copyWith(unreadCounts: counts));
    } catch (_) {}
  }
}
