import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/comments/comment_input_bar_widget.dart';
import 'package:skidoo_app/components/comments/comment_row_data.dart';
import 'package:skidoo_app/components/comments/comment_sheet_shell.dart';
import 'package:skidoo_app/components/comments/threaded_comment_widget.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/utils/time_formatter.dart';
import 'package:skidoo_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:skidoo_app/features/ads/presentation/bloc/feed_comment_bloc.dart';
import 'package:skidoo_app/models/photo_comment/photo_comment.dart';

/// Opens a bottom-sheet comment section for an ad or request.
///
/// [targetType] is 'ad' or 'request'.
/// [targetId] is the ad_id or request_id.
/// [commentsEnabled] hides the input when false.
class FeedCommentSheet {
  static void show(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String title,
    String? subtitle,
    bool commentsEnabled = true,
    VoidCallback? onCommentSent,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => BlocProvider(
        create: (_) => sl<FeedCommentBloc>()
          ..add(FeedCommentStarted(targetType, targetId)),
        child: _FeedCommentSheetContent(
          title: title,
          subtitle: subtitle,
          // Respect both the per-item flag and the global admin kill switch.
          commentsEnabled:
              commentsEnabled && AppConfigRepository.current.commentsEnabled,
          onCommentSent: onCommentSent,
        ),
      ),
    );
  }
}

// ── Sheet content ─────────────────────────────────────────────────────────────

class _FeedCommentSheetContent extends StatefulWidget {
  const _FeedCommentSheetContent({
    required this.title,
    this.subtitle,
    required this.commentsEnabled,
    this.onCommentSent,
  });

  final String title;
  final String? subtitle;
  final bool commentsEnabled;
  final VoidCallback? onCommentSent;

  @override
  State<_FeedCommentSheetContent> createState() =>
      _FeedCommentSheetContentState();
}

class _FeedCommentSheetContentState extends State<_FeedCommentSheetContent> {
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();

  PhotoComment? _replyingTo;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      context.read<FeedCommentBloc>().add(const FeedCommentLoadMoreRequested());
    }
  }

  void _startReply(PhotoComment comment) {
    setState(() => _replyingTo = comment);
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
    _focusNode.unfocus();
  }

  void _send() {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    context.read<FeedCommentBloc>().add(
          FeedCommentPosted(text, parentId: _replyingTo?.id),
        );
    // Only count top-level comments; replies don't change the card's count.
    if (_replyingTo == null) widget.onCommentSent?.call();
    _inputCtrl.clear();
    if (_replyingTo != null) setState(() => _replyingTo = null);
  }

  String _label(PhotoComment c, String myId) {
    if (c.userId == myId) return 'You';
    return c.userName.isNotEmpty ? c.userName : 'User';
  }

  CommentRowData _toRowData(
    PhotoComment c, {
    required String myId,
    List<PhotoComment>? replies,
    required VoidCallback onReply,
  }) {
    return CommentRowData(
      id: c.id,
      label: _label(c, myId),
      content: c.content,
      timeLabel: TimeFormatter.relative(c.createdAt),
      isMe: c.userId == myId,
      replyCount: replies?.length ?? c.replyCount,
      onReply: onReply,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return CommentSheetShell(
      title: widget.title,
      subtitle: widget.subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: BlocConsumer<FeedCommentBloc, FeedCommentState>(
              listenWhen: (prev, curr) =>
                  curr.errorMessage != null &&
                  curr.errorMessage != prev.errorMessage,
              listener: (_, state) =>
                  AppSnackBar.error(context, state.errorMessage!),
              builder: (_, state) {
                if (state.isLoading) return const AppLoadingIndicator();

                if (state.errorMessage != null && state.comments.isEmpty) {
                  return AppErrorView(
                    message: state.errorMessage!,
                    onRetry: () => context.read<FeedCommentBloc>().add(
                          FeedCommentStarted(state.targetType, state.targetId),
                        ),
                  );
                }

                return Column(
                  children: [
                    if (state.isPosting)
                      LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: ext.accentGold.withValues(alpha: 0.6),
                      ),

                    Expanded(
                      child: state.comments.isEmpty
                          ? CommentEmptyState(ext: ext)
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w, vertical: 8.h),
                              itemCount: state.comments.length +
                                  (state.isLoadingMore ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i == state.comments.length) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12.h),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        color: ext.accentGold,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  );
                                }
                                final comment = state.comments[i];
                                final replies =
                                    state.repliesMap[comment.id] ?? [];
                                final isExpanded =
                                    state.expandedRepliesFor.contains(comment.id);

                                return ThreadedCommentWidget(
                                  key: ValueKey(comment.id),
                                  comment: _toRowData(
                                    comment,
                                    myId: state.myUserId,
                                    replies: replies,
                                    onReply: () => _startReply(comment),
                                  ),
                                  replies: replies
                                      .map((r) => _toRowData(
                                            r,
                                            myId: state.myUserId,
                                            onReply: () => _startReply(comment),
                                          ))
                                      .toList(),
                                  ext: ext,
                                  isExpanded: isExpanded,
                                  onToggleReplies: () =>
                                      context.read<FeedCommentBloc>().add(
                                            FeedCommentRepliesRequested(comment.id),
                                          ),
                                );
                              },
                            ),
                    ),

                    if (widget.commentsEnabled)
                      CommentInputBarWidget(
                        controller: _inputCtrl,
                        focusNode: _focusNode,
                        onSend: _send,
                        ext: ext,
                        replyingToName: _replyingTo != null
                            ? _label(_replyingTo!, state.myUserId)
                            : null,
                        onCancelReply: _cancelReply,
                      )
                    else
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                                color: ext.searchHintColor.withValues(alpha: 0.15)),
                          ),
                        ),
                        child: Text(
                          'Comments are disabled',
                          style: TextStyle(
                              color: ext.searchHintColor, fontSize: 13.sp),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
