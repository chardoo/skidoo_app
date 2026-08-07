import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:jperg_app/features/photo_comments/data/photo_comment_remote_data_source.dart';
import 'package:jperg_app/models/photo_comment/photo_comment.dart';
import 'package:jperg_app/services/auth_service.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class PhotoCommentEvent extends Equatable {
  const PhotoCommentEvent();

  @override
  List<Object?> get props => [];
}

class PhotoCommentStarted extends PhotoCommentEvent {
  const PhotoCommentStarted(this.pictureId, this.myUserId);

  final String pictureId;
  final String myUserId;

  @override
  List<Object?> get props => [pictureId, myUserId];
}

class PhotoCommentLoadMoreRequested extends PhotoCommentEvent {
  const PhotoCommentLoadMoreRequested();
}

class PhotoCommentPosted extends PhotoCommentEvent {
  const PhotoCommentPosted(this.content, {this.parentId});

  final String content;
  final String? parentId;

  @override
  List<Object?> get props => [content, parentId];
}

class PhotoCommentRepliesRequested extends PhotoCommentEvent {
  const PhotoCommentRepliesRequested(this.commentId);

  final String commentId;

  @override
  List<Object?> get props => [commentId];
}

class PhotoCommentDeleted extends PhotoCommentEvent {
  const PhotoCommentDeleted(this.commentId);

  final String commentId;

  @override
  List<Object?> get props => [commentId];
}

class PhotoCommentEdited extends PhotoCommentEvent {
  const PhotoCommentEdited(this.commentId, this.content);

  final String commentId;
  final String content;

  @override
  List<Object?> get props => [commentId, content];
}

class PhotoCommentLikeToggled extends PhotoCommentEvent {
  const PhotoCommentLikeToggled();
}

// ── State ─────────────────────────────────────────────────────────────────────

class PhotoCommentState extends Equatable {
  const PhotoCommentState({
    this.pictureId = '',
    this.myUserId = '',
    this.comments = const [],
    this.repliesMap = const {},
    this.loadedRepliesFor = const {},
    this.expandedRepliesFor = const {},
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isPosting = false,
    this.hasReachedEnd = false,
    this.page = 1,
    this.errorMessage,
    this.likeCount = 0,
    this.isLiked = false,
  });

  final String pictureId;
  final String myUserId;
  final List<PhotoComment> comments;
  final Map<String, List<PhotoComment>> repliesMap;
  final Set<String> loadedRepliesFor;
  final Set<String> expandedRepliesFor;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isPosting;
  final bool hasReachedEnd;
  final int page;
  final String? errorMessage;
  final int likeCount;
  final bool isLiked;

  PhotoCommentState copyWith({
    String? pictureId,
    String? myUserId,
    List<PhotoComment>? comments,
    Map<String, List<PhotoComment>>? repliesMap,
    Set<String>? loadedRepliesFor,
    Set<String>? expandedRepliesFor,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isPosting,
    bool? hasReachedEnd,
    int? page,
    String? errorMessage,
    bool clearError = false,
    int? likeCount,
    bool? isLiked,
  }) {
    return PhotoCommentState(
      pictureId: pictureId ?? this.pictureId,
      myUserId: myUserId ?? this.myUserId,
      comments: comments ?? this.comments,
      repliesMap: repliesMap ?? this.repliesMap,
      loadedRepliesFor: loadedRepliesFor ?? this.loadedRepliesFor,
      expandedRepliesFor: expandedRepliesFor ?? this.expandedRepliesFor,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isPosting: isPosting ?? this.isPosting,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      page: page ?? this.page,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  @override
  List<Object?> get props => [
        pictureId,
        myUserId,
        comments,
        repliesMap,
        loadedRepliesFor,
        expandedRepliesFor,
        isLoading,
        isLoadingMore,
        isPosting,
        hasReachedEnd,
        page,
        errorMessage,
        likeCount,
        isLiked,
      ];
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class PhotoCommentBloc extends Bloc<PhotoCommentEvent, PhotoCommentState> {
  PhotoCommentBloc(this._dataSource, this._authService)
      : super(const PhotoCommentState()) {
    on<PhotoCommentStarted>(_onStarted);
    on<PhotoCommentLoadMoreRequested>(_onLoadMore);
    on<PhotoCommentPosted>(_onPosted);
    on<PhotoCommentRepliesRequested>(_onRepliesRequested);
    on<PhotoCommentDeleted>(_onDeleted);
    on<PhotoCommentEdited>(_onEdited);
    on<PhotoCommentLikeToggled>(_onLikeToggled);
  }

  final PhotoCommentRemoteDataSource _dataSource;
  final AuthService _authService;

  Future<void> _onStarted(
      PhotoCommentStarted event, Emitter<PhotoCommentState> emit) async {
    // Resolve userId: use provided value or fall back to AuthService
    final userId = event.myUserId.isNotEmpty
        ? event.myUserId
        : await _authService.getUserId();

    emit(state.copyWith(
      pictureId: event.pictureId,
      myUserId: userId,
      isLoading: true,
      clearError: true,
      comments: [],
      page: 1,
      hasReachedEnd: false,
    ));

    try {
      final comments =
          await _dataSource.getComments(event.pictureId, page: 1);
      emit(state.copyWith(
        comments: comments,
        isLoading: false,
        hasReachedEnd: comments.isEmpty,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }

    // Like status is non-critical — don't let it block comment loading.
    // clearError: true so a getComments error doesn't persist into this emit.
    try {
      final likeStatus =
          await _dataSource.getLikeStatus(event.pictureId, userId);
      emit(state.copyWith(
        likeCount: likeStatus.likes,
        isLiked: likeStatus.liked,
        clearError: true,
      ));
    } catch (_) {
      // Silently swallow — clear any lingering error from getComments too.
      emit(state.copyWith(clearError: true));
    }
  }

  Future<void> _onLoadMore(
      PhotoCommentLoadMoreRequested event,
      Emitter<PhotoCommentState> emit) async {
    if (state.isLoadingMore || state.hasReachedEnd) return;

    emit(state.copyWith(isLoadingMore: true, clearError: true));

    try {
      final nextPage = state.page + 1;
      final newComments = await _dataSource.getComments(
        state.pictureId,
        page: nextPage,
      );

      emit(state.copyWith(
        comments: [...state.comments, ...newComments],
        isLoadingMore: false,
        page: nextPage,
        hasReachedEnd: newComments.isEmpty,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onPosted(
      PhotoCommentPosted event, Emitter<PhotoCommentState> emit) async {
    emit(state.copyWith(isPosting: true, clearError: true));

    try {
      final comment = await _dataSource.postComment(
        state.pictureId,
        event.content,
        parentId: event.parentId,
      );

      if (event.parentId != null) {
        // Append reply to repliesMap and auto-expand the parent.
        final updatedReplies =
            Map<String, List<PhotoComment>>.from(state.repliesMap);
        updatedReplies[event.parentId!] = [
          ...(updatedReplies[event.parentId!] ?? []),
          comment,
        ];
        // Bump the reply count on the parent top-level comment.
        final updatedComments = state.comments.map((c) {
          if (c.id == event.parentId) {
            return c.copyWith(replyCount: c.replyCount + 1);
          }
          return c;
        }).toList();
        final updatedExpanded = Set<String>.from(state.expandedRepliesFor)
          ..add(event.parentId!);
        final updatedLoaded = Set<String>.from(state.loadedRepliesFor)
          ..add(event.parentId!);
        emit(state.copyWith(
          repliesMap: updatedReplies,
          comments: updatedComments,
          expandedRepliesFor: updatedExpanded,
          loadedRepliesFor: updatedLoaded,
          isPosting: false,
        ));
      } else {
        // Prepend top-level comment
        emit(state.copyWith(
          comments: [comment, ...state.comments],
          isPosting: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isPosting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRepliesRequested(
      PhotoCommentRepliesRequested event,
      Emitter<PhotoCommentState> emit) async {
    final alreadyLoaded = state.loadedRepliesFor.contains(event.commentId);

    if (alreadyLoaded) {
      // Toggle expanded state
      final updated = Set<String>.from(state.expandedRepliesFor);
      if (updated.contains(event.commentId)) {
        updated.remove(event.commentId);
      } else {
        updated.add(event.commentId);
      }
      emit(state.copyWith(expandedRepliesFor: updated));
      return;
    }

    try {
      final replies = await _dataSource.getReplies(event.commentId);
      final updatedReplies =
          Map<String, List<PhotoComment>>.from(state.repliesMap);
      updatedReplies[event.commentId] = replies;

      final updatedLoaded = Set<String>.from(state.loadedRepliesFor)
        ..add(event.commentId);
      final updatedExpanded = Set<String>.from(state.expandedRepliesFor)
        ..add(event.commentId);

      emit(state.copyWith(
        repliesMap: updatedReplies,
        loadedRepliesFor: updatedLoaded,
        expandedRepliesFor: updatedExpanded,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onDeleted(
      PhotoCommentDeleted event, Emitter<PhotoCommentState> emit) async {
    try {
      await _dataSource.deleteComment(event.commentId);

      // Remove from top-level comments
      final updatedComments =
          state.comments.where((c) => c.id != event.commentId).toList();

      // Remove from all reply lists
      final updatedReplies =
          Map<String, List<PhotoComment>>.from(state.repliesMap);
      for (final key in updatedReplies.keys.toList()) {
        updatedReplies[key] = updatedReplies[key]!
            .where((c) => c.id != event.commentId)
            .toList();
      }

      emit(state.copyWith(
        comments: updatedComments,
        repliesMap: updatedReplies,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onEdited(
      PhotoCommentEdited event, Emitter<PhotoCommentState> emit) async {
    try {
      final updated = await _dataSource.editComment(event.commentId, event.content);

      // Update in top-level comments
      final updatedComments = state.comments.map((c) {
        if (c.id == event.commentId) return updated;
        return c;
      }).toList();

      // Update in replies maps
      final updatedReplies =
          Map<String, List<PhotoComment>>.from(state.repliesMap);
      for (final key in updatedReplies.keys.toList()) {
        updatedReplies[key] = updatedReplies[key]!.map((c) {
          if (c.id == event.commentId) return updated;
          return c;
        }).toList();
      }

      emit(state.copyWith(
        comments: updatedComments,
        repliesMap: updatedReplies,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLikeToggled(
      PhotoCommentLikeToggled event, Emitter<PhotoCommentState> emit) async {
    // Optimistic update
    final wasLiked = state.isLiked;
    emit(state.copyWith(
      isLiked: !wasLiked,
      likeCount: state.likeCount + (wasLiked ? -1 : 1),
      clearError: true,
    ));

    try {
      final result = await _dataSource.toggleLike(state.pictureId);
      emit(state.copyWith(
        isLiked: result.liked,
        likeCount: result.likes,
      ));
    } catch (e) {
      // Revert optimistic update
      emit(state.copyWith(
        isLiked: wasLiked,
        likeCount: state.likeCount + (wasLiked ? 1 : -1),
        errorMessage: e.toString(),
      ));
    }
  }
}
