import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/campaigns_enabled.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/presentation/pages/my_campaigns_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/my_requests_page.dart';
import 'package:jperg_app/features/ads/presentation/widgets/create_bottom_sheet.dart';
import 'package:jperg_app/core/theme/app_icons.dart';

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
    with TickerProviderStateMixin {
  /// Rebuilt when the campaign switch moves: a TabController's length is fixed
  /// at construction, and the screen loses a tab when campaigns are switched
  /// off under it. [TickerProviderStateMixin] rather than the single-ticker
  /// one for the same reason — there is more than one controller over the life
  /// of this page.
  TabController? _tabs;
  bool? _tabsBuiltFor;

  final _repo = AdsRepository();

  int? _requestCount;
  int? _campaignCount;

  TabController _controllerFor(bool campaigns) {
    if (_tabsBuiltFor == campaigns && _tabs != null) return _tabs!;
    final previous = _tabs;
    _tabsBuiltFor = campaigns;
    _tabs = TabController(
      length: campaigns ? 2 : 1,
      vsync: this,
      // Campaigns off leaves one tab, and the initial index has to fit it —
      // arriving from "My Campaigns" with the feature switched off lands on
      // Requests rather than throwing.
      initialIndex: campaigns ? widget.initialTab.clamp(0, 1) : 0,
    );
    // Disposed after the frame that replaces it: the TabBar and TabBarView on
    // screen are still holding the old one until then.
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
    return _tabs!;
  }

  @override
  void dispose() {
    _tabs?.dispose();
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
    return CampaignsSwitch(builder: _buildPage);
  }

  Widget _buildPage(BuildContext context, bool campaigns) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final tabs = _controllerFor(campaigns);

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        leading: const AppBackButton(),
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
            tooltip: campaigns
                ? 'Post a request or start a campaign'
                : 'Post a request',
            icon: AppSvgIcon(AppIcons.add, color: ext.accentGold, size: 26.r),
            onPressed: () => CreateBottomSheet.show(context),
          ),
          SizedBox(width: AppSpacing.sm.w),
        ],
        // One tab is not a choice. With campaigns switched off this screen is
        // the requests list, and a lone "Requests" tab under a "Broadcasts"
        // title is a control that does nothing.
        bottom: !campaigns
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(46.h),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: tabs,
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
        controller: tabs,
        children: [
          MyRequestsPage(
            embedded: true,
            onCount: (n) {
              if (mounted) setState(() => _requestCount = n);
            },
          ),
          // Not built at all when campaigns are off: an offscreen tab still
          // mounts, and this one would fetch a campaign list for a feature
          // nobody can reach.
          if (campaigns)
            MyCampaignsPage(
              embedded: true,
              onCount: (n) {
                if (mounted) setState(() => _campaignCount = n);
              },
            ),
        ],
      ),
    );

    return page;
  }
}
