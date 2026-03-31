part of 'chat_room_bloc.dart';

class ChatRoomState extends Equatable {
  final List<ChatMessage> messages;
  final bool isConnected;
  final bool isConnecting;
  final bool isLoadingHistory;
  final bool isLoadingMore;
  final bool isSyncing;
  final bool hasReachedEnd;
  final String? errorMessage;

  const ChatRoomState({
    this.messages = const [],
    this.isConnected = false,
    this.isConnecting = false,
    this.isLoadingHistory = false,
    this.isLoadingMore = false,
    this.isSyncing = false,
    this.hasReachedEnd = false,
    this.errorMessage,
  });

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    bool? isConnected,
    bool? isConnecting,
    bool? isLoadingHistory,
    bool? isLoadingMore,
    bool? isSyncing,
    bool? hasReachedEnd,
    String? errorMessage,
    bool clearError = false,
  }) =>
      ChatRoomState(
        messages: messages ?? this.messages,
        isConnected: isConnected ?? this.isConnected,
        isConnecting: isConnecting ?? this.isConnecting,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isSyncing: isSyncing ?? this.isSyncing,
        hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      );

  @override
  List<Object?> get props => [
        messages,
        isConnected,
        isConnecting,
        isLoadingHistory,
        isLoadingMore,
        isSyncing,
        hasReachedEnd,
        errorMessage,
      ];
}
