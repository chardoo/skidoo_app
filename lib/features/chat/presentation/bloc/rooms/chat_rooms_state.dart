part of 'chat_rooms_bloc.dart';

class ChatRoomsState extends Equatable {
  final List<ChatRoom> rooms;

  /// Rooms where the current user has a pending invite (shown at the top).
  final List<ChatRoom> pendingInvites;

  /// True only when there are no cached rooms yet (first ever load).
  final bool isLoading;

  /// True while a background server sync is in progress.
  final bool isSyncing;

  /// Unread message count per room id.
  final Map<String, int> unreadCounts;

  /// Timestamp of the most recent message per room id (for sorting).
  final Map<String, DateTime> lastMessageAt;

  final String? errorMessage;

  /// The authenticated user's own ID — used to identify the other participant
  /// in direct rooms so we can show their name instead of "Direct message".
  final String currentUserId;

  const ChatRoomsState({
    this.rooms = const [],
    this.pendingInvites = const [],
    this.isLoading = false,
    this.isSyncing = false,
    this.unreadCounts = const {},
    this.lastMessageAt = const {},
    this.errorMessage,
    this.currentUserId = '',
  });

  ChatRoomsState copyWith({
    List<ChatRoom>? rooms,
    List<ChatRoom>? pendingInvites,
    bool? isLoading,
    bool? isSyncing,
    Map<String, int>? unreadCounts,
    Map<String, DateTime>? lastMessageAt,
    String? errorMessage,
    bool clearError = false,
    String? currentUserId,
  }) =>
      ChatRoomsState(
        rooms: rooms ?? this.rooms,
        pendingInvites: pendingInvites ?? this.pendingInvites,
        isLoading: isLoading ?? this.isLoading,
        isSyncing: isSyncing ?? this.isSyncing,
        unreadCounts: unreadCounts ?? this.unreadCounts,
        lastMessageAt: lastMessageAt ?? this.lastMessageAt,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        currentUserId: currentUserId ?? this.currentUserId,
      );

  @override
  List<Object?> get props => [
        rooms,
        pendingInvites,
        isLoading,
        isSyncing,
        unreadCounts,
        lastMessageAt,
        errorMessage,
        currentUserId,
      ];
}
