import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';

void main() {
  group('FollowEntry.fromJson', () {
    test('parses a following entry with notify and followedAt', () {
      final e = FollowEntry.fromJson(const {
        'id': 'abc',
        'type': 'photographer',
        'name': 'Jane Doe',
        'profile_url': 'https://cdn/x.jpg',
        'notify': true,
        'followedAt': '2026-06-02T10:00:00Z',
      });

      expect(e.id, 'abc');
      expect(e.type, 'photographer');
      expect(e.isPhotographer, isTrue);
      expect(e.name, 'Jane Doe');
      expect(e.profileUrl, 'https://cdn/x.jpg');
      expect(e.notify, isTrue);
      expect(e.followedAt, isNotNull);
    });

    test('followers entry without notify leaves notify null', () {
      final e = FollowEntry.fromJson(const {
        'id': 'c1',
        'type': 'client',
        'name': 'Sam',
        'profile_url': null,
        'followedAt': '2026-06-01T08:30:00Z',
      });

      expect(e.isPhotographer, isFalse);
      expect(e.notify, isNull);
      expect(e.profileUrl, isNull); // null profile_url stays null
    });

    test('empty / missing fields default safely', () {
      final e = FollowEntry.fromJson(const {});
      expect(e.id, '');
      expect(e.name, '');
      expect(e.profileUrl, isNull);
      expect(e.notify, isNull);
      expect(e.followedAt, isNull);
    });

    test('unparseable followedAt becomes null', () {
      final e = FollowEntry.fromJson(const {
        'id': 'x',
        'type': 'client',
        'name': 'Z',
        'followedAt': 'not-a-date',
      });
      expect(e.followedAt, isNull);
    });

    test('copyWith overrides only notify', () {
      const e = FollowEntry(id: 'i', type: 'client', name: 'N', notify: false);
      expect(e.copyWith(notify: true).notify, isTrue);
      expect(e.copyWith().notify, isFalse);
      expect(e.copyWith(notify: true).name, 'N');
    });
  });

  group('FollowPage', () {
    test('hasMore is true when page < totalPages', () {
      const p = FollowPage(
          data: [], page: 1, limit: 20, total: 42, totalPages: 3);
      expect(p.hasMore, isTrue);
    });

    test('hasMore is false on the last page', () {
      const p = FollowPage(
          data: [], page: 3, limit: 20, total: 42, totalPages: 3);
      expect(p.hasMore, isFalse);
    });

    test('empty constant has no pages', () {
      expect(FollowPage.empty.hasMore, isFalse);
      expect(FollowPage.empty.data, isEmpty);
    });
  });
}
