class PhotoComment {
  final String id;
  final String pictureId;
  final String userId;
  final String userName;
  final String userRole;
  final String content;
  final String? parentId;
  final int replyCount;
  final DateTime createdAt;

  /// The target's total comment count *after* this comment was created, as
  /// reported by the server. Null on anything read back from a list, on a
  /// reply (replies do not count towards the badge), and whenever the server
  /// could not read the count back — in all three cases the right move is to
  /// leave the displayed number alone rather than guess at a new one.
  final int? targetCommentCount;

  /// The heart on the row, and whether this reader is one of them. The count
  /// is the comment's own; `viewerLiked` is a fact about the pair and is filled
  /// in per request.
  final int likeCount;
  final bool viewerLiked;

  const PhotoComment({
    required this.id,
    required this.pictureId,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.content,
    this.parentId,
    required this.replyCount,
    required this.createdAt,
    this.targetCommentCount,
    this.likeCount = 0,
    this.viewerLiked = false,
  });

  factory PhotoComment.fromJson(Map<String, dynamic> json) {
    return PhotoComment(
      id: json['id']?.toString() ?? '',
      pictureId: json['picture_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      parentId: json['parent_id']?.toString(),
      replyCount: (json['reply_count'] as num?)?.toInt() ?? 0,
      targetCommentCount: (json['target_comment_count'] as num?)?.toInt(),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      viewerLiked: (json['viewer_liked'] as bool?) ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  PhotoComment copyWith({
    String? id,
    String? pictureId,
    String? userId,
    String? userName,
    String? userRole,
    String? content,
    String? parentId,
    int? replyCount,
    DateTime? createdAt,
    int? targetCommentCount,
    int? likeCount,
    bool? viewerLiked,
  }) {
    return PhotoComment(
      id: id ?? this.id,
      pictureId: pictureId ?? this.pictureId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      content: content ?? this.content,
      parentId: parentId ?? this.parentId,
      replyCount: replyCount ?? this.replyCount,
      createdAt: createdAt ?? this.createdAt,
      targetCommentCount: targetCommentCount ?? this.targetCommentCount,
      likeCount: likeCount ?? this.likeCount,
      viewerLiked: viewerLiked ?? this.viewerLiked,
    );
  }
}
