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

  /// Local file path of a staged image/video waiting to be sent.
  final String? pendingImagePath;

  /// True when the staged pending file is a video (not a still image).
  final bool pendingIsVideo;

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

  /// True once a shared E2EE session key exists for this DM room (both
  /// participants have published keys and X3DH has completed). Always false
  /// for non-DM rooms.
  final bool isE2EEReady;

  /// Transient notice shown when a user joins the room (e.g. "Bob joined").
  /// Cleared immediately after being shown.
  final String? systemNotice;

  /// The current room with up-to-date participants and settings.
  /// Updated reactively as WS admin/settings events arrive.
  final ChatRoom? room;

  /// True when the current user has admin rights in this group room.
  final bool amIAdmin;

  /// True while the leave-room API call is in-flight.
  final bool isLeaving;

  /// True while the delete-room API call is in-flight.
  final bool isDeleting;

  /// True once the room has been permanently deleted (or a room_deleted WS event
  /// was received). The UI should navigate away when this becomes true.
  final bool isDeleted;

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
    this.pendingIsVideo = false,
    this.replyingTo,
    this.eventLikes,
    this.eventDislikes,
    this.isEventLiked = false,
    this.isEventDisliked = false,
    this.pictureLikes,
    this.isPictureLiked = false,
    this.pendingShareUrl,
    this.myUserId = '',
    this.isE2EEReady = false,
    this.systemNotice,
    this.room,
    this.amIAdmin = false,
    this.isLeaving = false,
    this.isDeleting = false,
    this.isDeleted = false,
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
    bool? pendingIsVideo,
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
    bool? isE2EEReady,
    String? systemNotice,
    bool clearSystemNotice = false,
    ChatRoom? room,
    bool? amIAdmin,
    bool? isLeaving,
    bool? isDeleting,
    bool? isDeleted,
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
        pendingIsVideo: clearPendingImage ? false : (pendingIsVideo ?? this.pendingIsVideo),
        replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
        eventLikes: eventLikes ?? this.eventLikes,
        eventDislikes: eventDislikes ?? this.eventDislikes,
        isEventLiked: isEventLiked ?? this.isEventLiked,
        isEventDisliked: isEventDisliked ?? this.isEventDisliked,
        pictureLikes: pictureLikes ?? this.pictureLikes,
        isPictureLiked: isPictureLiked ?? this.isPictureLiked,
        pendingShareUrl: clearPendingShareUrl ? null : (pendingShareUrl ?? this.pendingShareUrl),
        myUserId: myUserId ?? this.myUserId,
        isE2EEReady: isE2EEReady ?? this.isE2EEReady,
        systemNotice: clearSystemNotice ? null : (systemNotice ?? this.systemNotice),
        room: room ?? this.room,
        amIAdmin: amIAdmin ?? this.amIAdmin,
        isLeaving: isLeaving ?? this.isLeaving,
        isDeleting: isDeleting ?? this.isDeleting,
        isDeleted: isDeleted ?? this.isDeleted,
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
        pendingIsVideo,
        replyingTo,
        eventLikes,
        eventDislikes,
        isEventLiked,
        isEventDisliked,
        pictureLikes,
        isPictureLiked,
        pendingShareUrl,
        myUserId,
        isE2EEReady,
        systemNotice,
        room,
        amIAdmin,
        isLeaving,
        isDeleting,
        isDeleted,
      ];
}
