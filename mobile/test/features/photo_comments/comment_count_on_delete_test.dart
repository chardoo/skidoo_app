import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:jperg_app/features/photo_comments/data/photo_comment_remote_data_source.dart';
import 'package:jperg_app/features/photo_comments/presentation/bloc/photo_comment_bloc.dart';
import 'package:jperg_app/models/photo_comment/photo_comment.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The other half of the badge that would not move.
///
/// Posting a comment already corrected the card behind the sheet — the create
/// response carries the new total and the bloc reports it. Deleting one did
/// not: the endpoint answered 204 with no body, so there was no number to
/// report, and the card went on showing the count it was built with until
/// something forced a refetch. On a cached feed that can be a long time, which
/// reads as the counter simply not working.
///
/// The fix is the same shape as create — the server says where the count
/// landed and the app repeats it. Deliberately not arithmetic: the bloc does
/// not hold the card's count, replies do not count towards the badge, and
/// somebody else may have commented since the sheet opened, so anything worked
/// out locally would be a guess that drifts.
class _FakeDataSource implements PhotoCommentRemoteDataSource {
  _FakeDataSource({this.countAfterDelete});

  /// What the server reports the target's total is once the delete lands.
  /// Null stands for a reply, or a count the server could not read back.
  final int? countAfterDelete;

  String? deletedId;

  @override
  Future<int?> deleteComment(String commentId) async {
    deletedId = commentId;
    return countAfterDelete;
  }

  @override
  Future<List<PhotoComment>> getComments(String pictureId,
          {int page = 1, int limit = 20}) async =>
      const [];

  @override
  Future<List<PhotoComment>> getReplies(String commentId,
          {int page = 1, int limit = 20}) async =>
      const [];

  @override
  Future<PhotoComment> postComment(String pictureId, String content,
          {String? parentId}) async =>
      throw UnimplementedError();

  @override
  Future<PhotoComment> editComment(String commentId, String content) async =>
      throw UnimplementedError();

  @override
  Future<({bool liked, int likes})> toggleLike(String pictureId) async =>
      (liked: false, likes: 0);

  @override
  Future<({bool liked, int likes})> getLikeStatus(
          String pictureId, String userId) async =>
      (liked: false, likes: 0);
}

/// A bloc already open on a photo's comment sheet.
///
/// `myUserId` is passed non-empty so the bloc never reaches for [AuthService] —
/// the delete path does not touch it, and a real one would want storage the
/// test has no business standing up.
Future<PhotoCommentBloc> openedOn(
  String pictureId,
  PhotoCommentRemoteDataSource source,
) async {
  final bloc = PhotoCommentBloc(source, AuthService());
  bloc.add(PhotoCommentStarted(pictureId, 'me'));
  await Future<void>.delayed(Duration.zero);
  return bloc;
}

void main() {
  setUp(CommentCounts.instance.clear);

  test('deleting a comment moves the card badge without a refetch', () async {
    final source = _FakeDataSource(countAfterDelete: 4);
    final bloc = await openedOn('pic-1', source);

    bloc.add(const PhotoCommentDeleted('c-1'));
    await Future<void>.delayed(Duration.zero);

    expect(source.deletedId, 'c-1');
    expect(CommentCounts.instance.countFor('pic-1'), 4);

    await bloc.close();
  });

  test('the last comment going leaves a zero, not a stale number', () async {
    final bloc = await openedOn('pic-1', _FakeDataSource(countAfterDelete: 0));

    bloc.add(const PhotoCommentDeleted('c-1'));
    await Future<void>.delayed(Duration.zero);

    expect(CommentCounts.instance.countFor('pic-1'), 0);

    await bloc.close();
  });

  test('deleting a reply leaves the badge alone', () async {
    // Replies never counted towards it, so the server reports null and the
    // displayed number must not move — least of all to zero.
    CommentCounts.instance.report('pic-1', 7);
    final bloc = await openedOn('pic-1', _FakeDataSource());

    bloc.add(const PhotoCommentDeleted('reply-1'));
    await Future<void>.delayed(Duration.zero);

    expect(CommentCounts.instance.countFor('pic-1'), 7);

    await bloc.close();
  });

  test('a failed delete does not move the badge', () async {
    CommentCounts.instance.report('pic-1', 7);
    final bloc = await openedOn('pic-1', _ThrowingDataSource());

    bloc.add(const PhotoCommentDeleted('c-1'));
    await Future<void>.delayed(Duration.zero);

    expect(CommentCounts.instance.countFor('pic-1'), 7);

    await bloc.close();
  });
}

class _ThrowingDataSource extends _FakeDataSource {
  @override
  Future<int?> deleteComment(String commentId) async =>
      throw Exception('offline');
}
