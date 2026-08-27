import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/features/ads/data/datasources/feed_comment_data_source.dart';
import 'package:jperg_app/models/photo_comment/photo_comment.dart';
import 'package:jperg_app/services/auth_service.dart';

// ── Events ────────────────────────────────────────────────────────────────────

abstract class FeedCommentEvent extends Equatable {
  const FeedCommentEvent();
  @override
  List<Object?> get props => [];
}

class FeedCommentStarted extends FeedCommentEvent {
  const FeedCommentStarted(this.targetType, this.targetId);
  final String targetType;
  final String targetId;
  @override
  List<Object?> get props => [targetType, targetId];
}

class FeedCommentLoadMoreRequested extends FeedCommentEvent {
  const FeedCommentLoadMoreRequested();
}

class FeedCommentPosted extends FeedCommentEvent {
  const FeedCommentPosted(this.content, {this.parentId});
  final String content;
  final String? parentId;
  @override
  List<Object?> get props => [content, parentId];
}

class FeedCommentRepliesRequested extends FeedCommentEvent {
  const FeedCommentRepliesRequested(this.commentId);
  final String commentId;
  @override
  List<Object?> get props => [commentId];
}

class FeedCommentDeleted extends FeedCommentEvent {
  const FeedCommentDeleted(this.commentId);
  final String commentId;
  @override
  List<Object?> get props => [commentId];
}

class FeedCommentEdited extends FeedCommentEvent {
  const FeedCommentEdited(this.commentId, this.content);
  final String commentId;
  final String content;
  @override
  List<Object?> get props => [commentId, content];
}

// ── State ─────────────────────────────────────────────────────────────────────

class FeedCommentState extends Equatable {
  const FeedCommentState({
    this.targetType = '',
    this.targetId = '',
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
  });

  final String targetType;
  final String targetId;
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

  FeedCommentState copyWith({
    String? targetType,
    String? targetId,
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
  }) {
    return FeedCommentState(
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
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
    );
  }

  @override
  List<Object?> get props => [
        targetType,
        targetId,
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
      ];
}

// ── BLoC ──────────────────────────────────────────────────────────────────────

class FeedCommentBloc extends Bloc<FeedCommentEvent, FeedCommentState> {
  FeedCommentBloc(this._dataSource, this._authService)
      : super(const FeedCommentState()) {
    on<FeedCommentStarted>(_onStarted);
    on<FeedCommentLoadMoreRequested>(_onLoadMore);
    on<FeedCommentPosted>(_onPosted);
    on<FeedCommentRepliesRequested>(_onRepliesRequested);
    on<FeedCommentDeleted>(_onDeleted);
    on<FeedCommentEdited>(_onEdited);
  }

  final FeedCommentDataSource _dataSource;
  final AuthService _authService;

  Future<void> _onStarted(
      FeedCommentStarted event, Emitter<FeedCommentState> emit) async {
    final userId = await _authService.getUserId();
    emit(state.copyWith(
      targetType: event.targetType,
      targetId: event.targetId,
      myUserId: userId,
      isLoading: true,
      clearError: true,
      comments: [],
      page: 1,
      hasReachedEnd: false,
    ));
    try {
      final comments = await _dataSource.getComments(
        event.targetType,
        event.targetId,
        page: 1,
      );
      emit(state.copyWith(
        comments: comments,
        isLoading: false,
        hasReachedEnd: comments.isEmpty,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMore(FeedCommentLoadMoreRequested event,
      Emitter<FeedCommentState> emit) async {
    if (state.isLoadingMore || state.hasReachedEnd) return;
    emit(state.copyWith(isLoadingMore: true, clearError: true));
    try {
      final nextPage = state.page + 1;
      final more = await _dataSource.getComments(
        state.targetType,
        state.targetId,
        page: nextPage,
      );
      emit(state.copyWith(
        comments: [...state.comments, ...more],
        isLoadingMore: false,
        page: nextPage,
        hasReachedEnd: more.isEmpty,
        clearError: true,
      ));
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onPosted(
      FeedCommentPosted event, Emitter<FeedCommentState> emit) async {
    emit(state.copyWith(isPosting: true, clearError: true));
    try {
      final comment = await _dataSource.postComment(
        state.targetType,
        state.targetId,
        event.content,
        parentId: event.parentId,
      );
      if (event.parentId != null) {
        final updatedReplies =
            Map<String, List<PhotoComment>>.from(state.repliesMap);
        updatedReplies[event.parentId!] = [
          ...(updatedReplies[event.parentId!] ?? []),
          comment,
        ];
        final updatedComments = state.comments.map((c) {
          if (c.id == event.parentId)
            return c.copyWith(replyCount: c.replyCount + 1);
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
        // The badge on whatever card opened this sheet reads its count from
        // immutable feed data that nothing rewrites, so without this it keeps
        // showing the number it was built with. The server's figure is used
        // rather than a local +1: replies do not count, this list is
        // paginated, and somebody else may have commented since it loaded.
        CommentCounts.instance.report(state.targetId, comment.targetCommentCount);
        emit(state.copyWith(
          comments: [comment, ...state.comments],
          isPosting: false,
        ));
      }
    } catch (e) {
      emit(state.copyWith(isPosting: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onRepliesRequested(
      FeedCommentRepliesRequested event, Emitter<FeedCommentState> emit) async {
    if (state.loadedRepliesFor.contains(event.commentId)) {
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
          Map<String, List<PhotoComment>>.from(state.repliesMap)
            ..[event.commentId] = replies;
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
      FeedCommentDeleted event, Emitter<FeedCommentState> emit) async {
    try {
      await _dataSource.deleteComment(event.commentId);
      final updatedComments =
          state.comments.where((c) => c.id != event.commentId).toList();
      final updatedReplies =
          Map<String, List<PhotoComment>>.from(state.repliesMap);
      for (final key in updatedReplies.keys.toList()) {
        updatedReplies[key] =
            updatedReplies[key]!.where((c) => c.id != event.commentId).toList();
      }
      emit(state.copyWith(
          comments: updatedComments,
          repliesMap: updatedReplies,
          clearError: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onEdited(
      FeedCommentEdited event, Emitter<FeedCommentState> emit) async {
    try {
      final updated =
          await _dataSource.editComment(event.commentId, event.content);
      final updatedComments = state.comments
          .map((c) => c.id == event.commentId ? updated : c)
          .toList();
      final updatedReplies =
          Map<String, List<PhotoComment>>.from(state.repliesMap);
      for (final key in updatedReplies.keys.toList()) {
        updatedReplies[key] = updatedReplies[key]!
            .map((c) => c.id == event.commentId ? updated : c)
            .toList();
      }
      emit(state.copyWith(
          comments: updatedComments,
          repliesMap: updatedReplies,
          clearError: true));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
