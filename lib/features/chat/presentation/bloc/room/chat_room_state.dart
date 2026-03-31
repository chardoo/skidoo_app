part of 'chat_room_bloc.dart';

class ChatRoomState extends Equatable {
  final List<ChatMessage> messages;
  final bool isConnected;
  final bool isConnecting;
  final bool isLoadingHistory;
  final bool isLoadingMore;
  final bool isSyncing;
  final bool hasReachedEnd;
  final bool isUploadingImage;
  final String? errorMessage;

  /// The message currently being replied to (null = no active reply).
  final ChatMessage? replyingTo;

  /// Like count for the event associated with this room (null for non-event rooms).
  final int? eventLikes;

  /// Whether the current user has liked the event.
  final bool isEventLiked;

  const ChatRoomState({
    this.messages = const [],
    this.isConnected = false,
    this.isConnecting = false,
    this.isLoadingHistory = false,
    this.isLoadingMore = false,
    this.isSyncing = false,
    this.hasReachedEnd = false,
    this.isUploadingImage = false,
    this.errorMessage,
    this.replyingTo,
    this.eventLikes,
    this.isEventLiked = false,
  });

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    bool? isConnected,
    bool? isConnecting,
    bool? isLoadingHistory,
    bool? isLoadingMore,
    bool? isSyncing,
    bool? hasReachedEnd,
    bool? isUploadingImage,
    String? errorMessage,
    bool clearError = false,
    ChatMessage? replyingTo,
    bool clearReply = false,
    int? eventLikes,
    bool? isEventLiked,
  }) =>
      ChatRoomState(
        messages: messages ?? this.messages,
        isConnected: isConnected ?? this.isConnected,
        isConnecting: isConnecting ?? this.isConnecting,
        isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        isSyncing: isSyncing ?? this.isSyncing,
        hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
        isUploadingImage: isUploadingImage ?? this.isUploadingImage,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
        eventLikes: eventLikes ?? this.eventLikes,
        isEventLiked: isEventLiked ?? this.isEventLiked,
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
        isUploadingImage,
        errorMessage,
        replyingTo,
        eventLikes,
        isEventLiked,
      ];
}
