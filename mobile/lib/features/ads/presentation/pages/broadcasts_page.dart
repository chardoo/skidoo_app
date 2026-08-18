import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/presentation/pages/my_campaigns_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/my_requests_page.dart';
import 'package:jperg_app/features/ads/presentation/widgets/create_bottom_sheet.dart';

/// "Broadcasts" — everything the user has put out: their requests, and the
/// campaigns they are running.
///
/// The two lists were separate screens reached from a settings list. They are
/// tabs here, with the counts in the labels, because both answer the same
/// question and a user with neither should see the emptiness of both at once.
class BroadcastsPage extends StatefulWidget {
  const BroadcastsPage({super.key, this.initialTab = 0});

  /// 0 = Requests, 1 = Campaigns.
  final int initialTab;

  @override
  State<BroadcastsPage> createState() => _BroadcastsPageState();
}

class _BroadcastsPageState extends State<BroadcastsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _repo = AdsRepository();

  int? _requestCount;
  int? _campaignCount;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// The counts come from the two lists below, which are already fetching
  /// exactly this data. Broadcasts used to fetch both lists again itself, one
  /// after the other, purely to put a number in a label — four list calls to
  /// show two lists, two of them blocking the tabs from appearing.
  String _label(String name, int? count) =>
      count == null ? name : '$name ($count)';

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: kIsWeb
            ? null
            : const AppBackButton(),
        title: Text(
          'Broadcasts',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Post a request or start a campaign',
            icon: Icon(Icons.add_rounded, color: ext.accentGold, size: 26.r),
            onPressed: () => CreateBottomSheet.show(context),
          ),
          SizedBox(width: AppSpacing.sm.w),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(46.h),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: ext.accentGold,
              labelColor: ext.greetingColor,
              unselectedLabelColor: ext.searchHintColor,
              labelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(text: _label('Requests', _requestCount)),
                Tab(text: _label('Campaigns', _campaignCount)),
              ],
            ),
          ),
        ),
      ),
      // Both children are full pages with their own scaffolds and app bars,
      // which would stack a second header inside each tab — they are embedded
      // here instead, see `embedded` on each.
      body: TabBarView(
        controller: _tabs,
        children: [
          MyRequestsPage(
            embedded: true,
            onCount: (n) {
              if (mounted) setState(() => _requestCount = n);
            },
          ),
          MyCampaignsPage(
            embedded: true,
            onCount: (n) {
              if (mounted) setState(() => _campaignCount = n);
            },
          ),
        ],
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
