part of 'chat_rooms_bloc.dart';

class ChatRoomsState extends Equatable {
  final List<ChatRoom> rooms;

  /// True only when there are no cached rooms yet (first ever load).
  final bool isLoading;

  /// True while a background server sync is in progress.
  final bool isSyncing;

  /// Unread message count per room id.
  final Map<String, int> unreadCounts;

  final String? errorMessage;

  const ChatRoomsState({
    this.rooms = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.unreadCounts = const {},
    this.errorMessage,
  });

  ChatRoomsState copyWith({
    List<ChatRoom>? rooms,
    bool? isLoading,
    bool? isSyncing,
    Map<String, int>? unreadCounts,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ChatRoomsState(
        rooms: rooms ?? this.rooms,
        isLoading: isLoading ?? this.isLoading,
        isSyncing: isSyncing ?? this.isSyncing,
        unreadCounts: unreadCounts ?? this.unreadCounts,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props =>
      [rooms, isLoading, isSyncing, unreadCounts, errorMessage];
}
