import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_error_view.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _repo = sl<AppConfigRepository>();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  late bool _adsEnabled;
  late bool _requestsEnabled;
  late bool _commentsEnabled;
  late int _adsEvery;
  late int _requestsEvery;
  late double _minBudget;

  @override
  void initState() {
    super.initState();
    _applyConfig(AppConfigRepository.current);
    _load();
  }

  void _applyConfig(AppConfig c) {
    _adsEnabled = c.adsEnabled;
    _requestsEnabled = c.requestsEnabled;
    _commentsEnabled = c.commentsEnabled;
    _adsEvery = c.adsEveryNEvents;
    _requestsEvery = c.requestsEveryNEvents;
    _minBudget = c.minCampaignBudgetGhs;
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final config = await _repo.fetch();
      if (mounted) setState(() { _applyConfig(config); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _repo.update(AppConfig(
        adsEnabled: _adsEnabled,
        requestsEnabled: _requestsEnabled,
        commentsEnabled: _commentsEnabled,
        adsEveryNEvents: _adsEvery,
        requestsEveryNEvents: _requestsEvery,
        minCampaignBudgetGhs: _minBudget,
      ));
      if (!mounted) return;
      AppSnackBar.success(context, 'Settings saved.');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        title: Text(
          'Admin Settings',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: ext.greetingColor),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: ext.accentGold),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(
                        color: ext.accentGold,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _load)
              : ListView(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: AppSpacing.lg.h),
                  children: [
                    _SectionHeader('Feed Visibility', ext),
                    _ConfigCard(ext: ext, children: [
                      _Toggle(
                        label: 'Show ads in feed',
                        subtitle: 'Display sponsored ad cards between events',
                        value: _adsEnabled,
                        onChanged: (v) => setState(() => _adsEnabled = v),
                        ext: ext,
                      ),
                      _Divider(ext),
                      _Toggle(
                        label: 'Show requests in feed',
                        subtitle: 'Display community request cards between events',
                        value: _requestsEnabled,
                        onChanged: (v) => setState(() => _requestsEnabled = v),
                        ext: ext,
                      ),
                    ]),

                    SizedBox(height: AppSpacing.xl.h),
                    _SectionHeader('Feed Frequency', ext),
                    _ConfigCard(ext: ext, children: [
                      _StepperRow(
                        label: 'Ad every N events',
                        subtitle: 'Show an ad after every N events (min 5)',
                        value: _adsEvery,
                        min: 5,
                        max: 50,
                        onChanged: (v) => setState(() => _adsEvery = v),
                        ext: ext,
                      ),
                      _Divider(ext),
                      _StepperRow(
                        label: 'Request every N events',
                        subtitle: 'Show a request after every N events (min 5)',
                        value: _requestsEvery,
                        min: 5,
                        max: 100,
                        onChanged: (v) => setState(() => _requestsEvery = v),
                        ext: ext,
                      ),
                    ]),

                    SizedBox(height: AppSpacing.xl.h),
                    _SectionHeader('Comments', ext),
                    _ConfigCard(ext: ext, children: [
                      _Toggle(
                        label: 'Comments enabled globally',
                        subtitle: 'Kill switch — hides all comment sections when off',
                        value: _commentsEnabled,
                        onChanged: (v) => setState(() => _commentsEnabled = v),
                        ext: ext,
                      ),
                    ]),

                    SizedBox(height: AppSpacing.xl.h),
                    _SectionHeader('Campaign Limits', ext),
                    _ConfigCard(ext: ext, children: [
                      _BudgetRow(
                        label: 'Min campaign budget (GHS)',
                        subtitle: 'Reject campaigns below this total budget',
                        value: _minBudget,
                        onChanged: (v) => setState(() => _minBudget = v),
                        ext: ext,
                      ),
                    ]),

                    SizedBox(height: AppSpacing.xxxl.h),
                  ],
                ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

}

// ── UI helpers ────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label, this.ext);
  final String label;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: ext.searchHintColor,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ConfigCard extends StatelessWidget {
  const _ConfigCard({required this.ext, required this.children});
  final AppThemeExtension ext;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: ext.searchHintColor.withValues(alpha: 0.1),
          width: 0.8,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider(this.ext);
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 16.w,
      endIndent: 16.w,
      color: ext.searchHintColor.withValues(alpha: 0.12),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.ext,
  });
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label,
          style: TextStyle(color: ext.greetingColor, fontSize: 14.sp)),
      subtitle: Text(subtitle,
          style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp)),
      activeThumbColor: ext.accentGold,
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.ext,
  });
  final String label;
  final String subtitle;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: AppSpacing.md.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: ext.greetingColor, fontSize: 14.sp)),
                SizedBox(height: 2.h),
                Text(subtitle,
                    style: TextStyle(
                        color: ext.searchHintColor, fontSize: 12.sp)),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md.w),
          Row(
            children: [
              _StepBtn(
                icon: Icons.remove,
                onTap: value > min ? () => onChanged(value - 1) : null,
                ext: ext,
              ),
              SizedBox(width: AppSpacing.sm.w),
              SizedBox(
                width: 34.w,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              _StepBtn(
                icon: Icons.add,
                onTap: value < max ? () => onChanged(value + 1) : null,
                ext: ext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, required this.onTap, required this.ext});
  final IconData icon;
  final VoidCallback? onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, label: 'Step', child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30.w,
        height: 30.w,
        decoration: BoxDecoration(
          color: onTap != null
              ? ext.accentGold.withValues(alpha: 0.12)
              : ext.searchFieldFill,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16.sp,
          color: onTap != null ? ext.accentGold : ext.searchHintColor,
        ),
      ),
    ));
  }
}

class _BudgetRow extends StatefulWidget {
  const _BudgetRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.ext,
  });
  final String label;
  final String subtitle;
  final double value;
  final ValueChanged<double> onChanged;
  final AppThemeExtension ext;

  @override
  State<_BudgetRow> createState() => _BudgetRowState();
}

class _BudgetRowState extends State<_BudgetRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: AppSpacing.md.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    style: TextStyle(color: ext.greetingColor, fontSize: 14.sp)),
                SizedBox(height: 2.h),
                Text(widget.subtitle,
                    style:
                        TextStyle(color: ext.searchHintColor, fontSize: 12.sp)),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md.w),
          SizedBox(
            width: 80.w,
            child: AppTextField(
              controller: _ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              dense: true,
              borderRadius: 8.r,
              prefixText: 'GH₵ ',
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null && parsed >= 0) widget.onChanged(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
}
