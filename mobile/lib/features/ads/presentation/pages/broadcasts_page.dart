import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/presentation/pages/my_campaigns_page.dart';
import 'package:skidoo_app/features/ads/presentation/pages/my_requests_page.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/create_bottom_sheet.dart';

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
    _loadCounts();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// The tab labels carry counts, and the lists inside fetch their own pages —
  /// so the counts are read once here rather than lifted out of two child
  /// widgets that load independently. A failure leaves the label bare rather
  /// than showing a wrong number.
  Future<void> _loadCounts() async {
    try {
      final requests = await _repo.getMyRequests();
      if (mounted) setState(() => _requestCount = requests.length);
    } catch (_) {
      if (mounted) setState(() => _requestCount = null);
    }
    try {
      final campaigns = await _repo.getMyCampaigns();
      if (mounted) setState(() => _campaignCount = campaigns.length);
    } catch (_) {
      if (mounted) setState(() => _campaignCount = null);
    }
  }

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
            : AppBackButton(onPressed: () => Navigator.of(context).pop()),
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
        children: const [
          MyRequestsPage(embedded: true),
          MyCampaignsPage(embedded: true),
        ],
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}
