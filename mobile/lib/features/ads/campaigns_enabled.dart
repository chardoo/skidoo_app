import 'package:flutter/widgets.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';

/// Whether campaigns exist in this app at all, right now.
///
/// One switch, thrown by the super admin (`ads_enabled` on `/config`), and the
/// whole product answers to it: no campaign in the feed, no campaign in the
/// Create sheet, no Campaigns tab, no campaign screens reachable by link. What
/// is left is requests, which are a separate product with their own switch —
/// see [AppConfig.requestsEnabled] and `request_board_access.dart`.
///
/// It is deliberately *not* a role test. Anyone may buy a campaign; this is
/// about whether the feature is switched on, not about who is asking.
///
/// **Read this through [CampaignsSwitch], not once at build time.** The switch
/// moves while the app is running — an admin flips it on a dashboard and every
/// installed app has to follow within the session, without a restart. A screen
/// that read the flag once keeps showing campaigns that no longer exist, or
/// keeps hiding a feature that has been turned back on, until it happens to be
/// rebuilt for some unrelated reason. That was the whole bug: the flag was
/// honoured in three places and slept through every change in all of them.
bool get campaignsEnabled => AppConfigRepository.current.adsEnabled;

/// Rebuilds [builder] whenever the campaign switch moves.
///
/// The wake-up half of [campaignsEnabled]: config arrives after launch (the
/// first `/config` is fire-and-forget) and again whenever the app returns to
/// the foreground, so "enabled" is an answer that changes under a live screen.
class CampaignsSwitch extends StatelessWidget {
  const CampaignsSwitch({super.key, required this.builder});

  final Widget Function(BuildContext context, bool enabled) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppConfig>(
      valueListenable: AppConfigRepository.notifier,
      builder: (context, config, _) => builder(context, config.adsEnabled),
    );
  }
}
