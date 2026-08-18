import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/data/datasources/user_search_data_source.dart';
import 'package:jperg_app/features/chat/presentation/widgets/member_picker.dart';
import 'package:jperg_app/models/chat/shareable_user.dart';

/// Creating a group and adding people to one are the same screen. These pin the
/// two things that differ — the confirm label, and who is off-limits — so the
/// add-member screen can't quietly grow its own layout again.
class _FakeSearch extends UserSearchDataSource {
  _FakeSearch(this.users) : super(Api());

  final List<ShareableUser> users;

  @override
  Future<UserSearchPage> search(String query, {int page = 1, int limit = 25}) async =>
      UserSearchPage(users: users, hasMore: false);
}

ShareableUser _user(String id, String name) =>
    ShareableUser(id: id, name: name, role: 'client');

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: child,
      ),
    );

Future<void> _search(WidgetTester t) async {
  await t.enterText(find.byType(TextField).first, 'a');
  await t.pump(const Duration(milliseconds: 400));
  await t.pumpAndSettle();
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  tearDown(() => sl.reset());

  testWidgets('the confirm action is whatever the caller calls it', (t) async {
    sl.registerSingleton<UserSearchDataSource>(_FakeSearch([]));

    await t.pumpWidget(host(MemberPicker(
      actionLabel: 'Add',
      onSubmit: (_) async {},
    )));
    await t.pumpAndSettle();

    expect(find.text('Add Members'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('picking people enables the action and hands them over',
      (t) async {
    sl.registerSingleton<UserSearchDataSource>(
        _FakeSearch([_user('u2', 'Sarah Johnson'), _user('u3', 'Kojo Mensah')]));

    List<ShareableUser>? submitted;
    await t.pumpWidget(host(MemberPicker(
      actionLabel: 'Add',
      onSubmit: (users) async => submitted = users,
    )));
    await t.pumpAndSettle();

    // Nothing picked yet, so confirming does nothing.
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();
    expect(submitted, isNull);

    await _search(t);
    await t.tap(find.text('Sarah Johnson'));
    await t.pumpAndSettle();
    await t.tap(find.text('Add'));
    await t.pumpAndSettle();

    expect(submitted?.map((u) => u.id).toList(), ['u2']);
  });

  testWidgets('people already in the group are not offered again', (t) async {
    sl.registerSingleton<UserSearchDataSource>(
        _FakeSearch([_user('u2', 'Sarah Johnson'), _user('u3', 'Kojo Mensah')]));

    await t.pumpWidget(host(MemberPicker(
      actionLabel: 'Add',
      excludedUserIds: const {'u2'},
      onSubmit: (_) async {},
    )));
    await t.pumpAndSettle();
    await _search(t);

    expect(find.text('Kojo Mensah'), findsOneWidget);
    expect(find.text('Sarah Johnson'), findsNothing);
  });
}
