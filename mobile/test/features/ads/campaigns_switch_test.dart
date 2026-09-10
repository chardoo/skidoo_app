/// The super admin's campaign switch, and whether the app notices it moving.
///
/// Two halves, and the app only ever had the first: honouring the flag where
/// it is read, and *hearing* it change. The flags are fetched once at launch,
/// so switching campaigns off reached nobody who already had the app open, and
/// switching them back on reached nobody until they force-quit. What follows
/// pins both — the Create sheet is the entry point the switch is most visible
/// at, and it must follow the flag without being reopened.
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_watcher.dart';
import 'package:jperg_app/features/ads/campaigns_enabled.dart';
import 'package:jperg_app/features/ads/presentation/widgets/create_bottom_sheet.dart';

Widget _wrap(Widget child) => ScreenUtilInit(
      designSize: const Size(412, 917),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

/// A phone-sized surface, so the sheet lays out the way it ships rather than
/// against the default 800×600 desktop one.
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412 * 3, 917 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void _config({bool campaigns = true, bool requests = true}) {
  AppConfigRepository.current =
      AppConfig(adsEnabled: campaigns, requestsEnabled: requests);
}

void main() {
  setUp(() => _config());
  tearDown(() => AppConfigRepository.current = const AppConfig());

  group('the Create sheet — what the "+" offers', () {
    testWidgets('campaigns off leaves only the request', (tester) async {
      _phone(tester);
      _config(campaigns: false);

      await tester.pumpWidget(_wrap(const CreateBottomSheet()));
      await tester.pumpAndSettle();

      expect(find.text('Request a photographer'), findsOneWidget);
      expect(find.text('Start a campaign'), findsNothing);
    });

    testWidgets('campaigns on offers both', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(const CreateBottomSheet()));
      await tester.pumpAndSettle();

      expect(find.text('Request a photographer'), findsOneWidget);
      expect(find.text('Start a campaign'), findsOneWidget);
    });

    testWidgets('the sheet follows the switch while it is open',
        (tester) async {
      // The bug this pins: the flag was read once at build, so a sheet already
      // on screen went on offering a campaign the admin had just switched off
      // — and went on hiding one that had just been switched back on.
      _phone(tester);
      await tester.pumpWidget(_wrap(const CreateBottomSheet()));
      await tester.pumpAndSettle();
      expect(find.text('Start a campaign'), findsOneWidget);

      _config(campaigns: false);
      await tester.pumpAndSettle();
      expect(find.text('Start a campaign'), findsNothing);

      _config();
      await tester.pumpAndSettle();
      expect(find.text('Start a campaign'), findsOneWidget,
          reason: 'switching it back on has to wake the sheet up too');
    });

    testWidgets('requests off leaves only the campaign', (tester) async {
      // The other switch is its own product and moves on its own.
      _phone(tester);
      _config(requests: false);

      await tester.pumpWidget(_wrap(const CreateBottomSheet()));
      await tester.pumpAndSettle();

      expect(find.text('Request a photographer'), findsNothing);
      expect(find.text('Start a campaign'), findsOneWidget);
    });
  });

  group('CampaignsSwitch', () {
    testWidgets('rebuilds when the flag moves', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_wrap(CampaignsSwitch(
        builder: (_, enabled) => Text(enabled ? 'on' : 'off'),
      )));
      await tester.pumpAndSettle();
      expect(find.text('on'), findsOneWidget);

      _config(campaigns: false);
      await tester.pumpAndSettle();
      expect(find.text('off'), findsOneWidget);
    });

    test('campaignsEnabled reads the live config', () {
      _config(campaigns: false);
      expect(campaignsEnabled, isFalse);
      _config();
      expect(campaignsEnabled, isTrue);
    });
  });

  group('AppConfigWatcher — hearing the switch move', () {
    test('refetches on a resume', () async {
      var fetches = 0;
      final watcher = AppConfigWatcher(() async => fetches++);
      final start = DateTime(2026, 1, 1, 9);
      watcher.start(now: start);
      addTearDown(watcher.stop);

      // Launch already fetched, so an immediate resume is not worth a request.
      expect(await watcher.refresh(now: start.add(const Duration(seconds: 5))),
          isFalse);
      expect(fetches, 0);

      expect(await watcher.refresh(now: start.add(const Duration(minutes: 5))),
          isTrue);
      expect(fetches, 1);
    });

    test('a run of quick resumes is one fetch, not five', () async {
      var fetches = 0;
      final watcher = AppConfigWatcher(() async => fetches++);
      final start = DateTime(2026, 1, 1, 9);
      watcher.start(now: start.subtract(const Duration(hours: 1)));
      addTearDown(watcher.stop);

      for (var i = 0; i < 5; i++) {
        await watcher.refresh(now: start.add(Duration(seconds: i)));
      }

      expect(fetches, 1);
    });

    test('stop is safe to call twice, and start only registers once', () {
      final watcher = AppConfigWatcher(() async {});
      watcher.start();
      watcher.start();
      watcher.stop();
      watcher.stop();
    });
  });
}
