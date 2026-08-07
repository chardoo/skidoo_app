import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/models/ad_campaign.dart';
import 'package:jperg_app/features/ads/presentation/pages/campaign_details_page.dart';
import 'package:jperg_app/features/ads/presentation/pages/campaign_wizard_page.dart';
import 'package:jperg_app/features/ads/presentation/widgets/campaign_row.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

class MyCampaignsPage extends StatefulWidget {
  const MyCampaignsPage({super.key, this.embedded = false, this.onCount});

  /// True when this list is a tab inside Broadcasts, which already provides
  /// the header and the back button — so it renders as a bare list rather
  /// than a second page stacked inside the first.
  final bool embedded;

  /// How many this list holds, reported once it knows. Broadcasts puts it in
  /// the tab label — it used to fetch the whole list again to find out.
  final ValueChanged<int>? onCount;

  @override
  State<MyCampaignsPage> createState() => _MyCampaignsPageState();
}

/// Kept alive for the same reason as [MyRequestsPage]: the Broadcasts
/// [TabBarView] disposes the off-screen tab, so without this every switch back
/// refetched the campaign list from scratch.
class _MyCampaignsPageState extends State<MyCampaignsPage>
    with AutomaticKeepAliveClientMixin {
  final _repo = AdsRepository();
  List<AdCampaign> _campaigns = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    debugPrint('[MyCampaignsPage] _load');
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final campaigns = await _repo.getMyCampaigns();
      if (!mounted) return;
      debugPrint('[MyCampaignsPage] loaded ${campaigns.length} campaigns');
      setState(() {
        _campaigns = campaigns;
        widget.onCount?.call(campaigns.length);
        _loading = false;
      });
    } catch (e) {
      debugPrint('[MyCampaignsPage] _load ERROR: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load your campaigns.';
        _loading = false;
      });
    }
  }




  Future<void> _showEditSheet(AdCampaign campaign) async {
    // Straight through on what the list already has. The details screen
    // refetches on init for the ad sets and the performance figures, so
    // fetching here as well meant two trips for one screen — and the first
    // blocked anything at all from appearing.
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CampaignDetailsPage(campaign: campaign),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: widget.embedded ? null : AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: kIsWeb
            ? null
            : AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(
          'My Campaigns',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const AppLoadingIndicator()
          : _errorMessage != null
              ? AppErrorView(
                  message: _errorMessage!,
                  icon: Icons.cloud_off_outlined,
                  onRetry: _load,
                )
              : _campaigns.isEmpty
                  ? AppEmptyState(
                      icon: Icons.rocket_launch_outlined,
                      message: 'No campaigns yet!',
                      // The design makes the second line the way out, not a
                      // sentence to read — so it is the action, and it opens
                      // the wizard.
                      action: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CampaignWizardPage(),
                          ),
                        ).then((_) => _load()),
                        child: Text(
                          'Create a campaign to get started.',
                          style: TextStyle(
                            color: ext.accentGold,
                            fontSize: 13.sp,
                            decoration: TextDecoration.underline,
                            decorationColor: ext.accentGold,
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: ext.accentGold,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.only(bottom: AppSpacing.xl.h),
                        itemCount: _campaigns.length,
                        itemBuilder: (_, i) => CampaignRow(
                          campaign: _campaigns[i],
                          ext: ext,
                          onTap: () => _showEditSheet(_campaigns[i]),
                        ),
                      ),
                    ),
    );
    return widget.embedded
        ? page
        : webWrap(page, backgroundColor: ext.homeBackground);
  }
}


