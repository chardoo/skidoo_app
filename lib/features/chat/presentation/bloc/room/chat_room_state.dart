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

  /// Local file path of a staged image waiting to be sent.
  final String? pendingImagePath;

  /// The message currently being replied to (null = no active reply).
  final ChatMessage? replyingTo;

  /// Like count for the event associated with this room (null for non-event rooms).
  final int? eventLikes;

  /// Dislike count for the event associated with this room.
  final int? eventDislikes;

  /// Whether the current user has liked the event.
  final bool isEventLiked;

  /// Whether the current user has disliked the event.
  final bool isEventDisliked;

  /// Like count for the picture in a photo room (null for non-photo rooms).
  final int? pictureLikes;

  /// Whether the current user has liked the picture.
  final bool isPictureLiked;

  /// A remote image URL queued to be sent as a message once the WS connects.
  final String? pendingShareUrl;

  /// The authenticated user's ID — set synchronously in [ChatRoomJoined] so
  /// the UI never has to async-load it separately.
  final String myUserId;

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
    this.pendingImagePath,
    this.replyingTo,
    this.eventLikes,
    this.eventDislikes,
    this.isEventLiked = false,
    this.isEventDisliked = false,
    this.pictureLikes,
    this.isPictureLiked = false,
    this.pendingShareUrl,
    this.myUserId = '',
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
    String? pendingImagePath,
    bool clearPendingImage = false,
    ChatMessage? replyingTo,
    bool clearReply = false,
    int? eventLikes,
    int? eventDislikes,
    bool? isEventLiked,
    bool? isEventDisliked,
    int? pictureLikes,
    bool? isPictureLiked,
    String? pendingShareUrl,
    bool clearPendingShareUrl = false,
    String? myUserId,
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
        pendingImagePath: clearPendingImage ? null : (pendingImagePath ?? this.pendingImagePath),
        replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
        eventLikes: eventLikes ?? this.eventLikes,
        eventDislikes: eventDislikes ?? this.eventDislikes,
        isEventLiked: isEventLiked ?? this.isEventLiked,
        isEventDisliked: isEventDisliked ?? this.isEventDisliked,
        pictureLikes: pictureLikes ?? this.pictureLikes,
        isPictureLiked: isPictureLiked ?? this.isPictureLiked,
        pendingShareUrl: clearPendingShareUrl ? null : (pendingShareUrl ?? this.pendingShareUrl),
        myUserId: myUserId ?? this.myUserId,
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
        pendingImagePath,
        replyingTo,
        eventLikes,
        eventDislikes,
        isEventLiked,
        isEventDisliked,
        pictureLikes,
        isPictureLiked,
        pendingShareUrl,
        myUserId,
      ];
}
