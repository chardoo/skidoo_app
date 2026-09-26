import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_filter_chips.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/common/widgets/app_empty_state.dart';
import 'package:jperg_app/core/common/widgets/app_loading_indicator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/features/settings/data/payments_api.dart';
import 'package:jperg_app/features/settings/presentation/widgets/payment_receipt_sheet.dart';

/// Everything this account has paid, and everything it has been paid.
///
/// The money was spread across three screens that each showed one slice —
/// bought photos in the gallery, ad spend in the campaign pages, payouts in
/// Earnings — and none of them answered the question somebody actually has:
/// *what did I pay, and did it go through*. A failed payment in particular had
/// nowhere to appear at all.
///
/// Two endpoints, one list: `main` reports photo purchases and payouts, the
/// ads service reports boosts, campaigns and booking deposits. See
/// [PaymentsApi] for why they are merged here rather than upstream.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key, PaymentsApi? api}) : _api = api;

  final PaymentsApi? _api;

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

/// The filters, in the order somebody reaches for them.
///
/// Kind first, status second. Both are lists rather than a single combined
/// control: a pending purchase is two answers, not a seventh chip.
enum _Kind {
  all('All', null),
  purchases('Purchases', 'purchase'),
  bookings('Bookings', 'booking'),

  // ── Studio money, which this screen does not show ───────────────────────
  //
  // Boosts, campaign spend and payouts belong to running a business, and the
  // studio that runs it is on the web. Kept named here rather than deleted
  // because [PaymentsApi] still merges both services and these are what comes
  // back from the ads half — a kind this file cannot name is a kind it cannot
  // filter out, and it would fall through into the list as an unlabelled row.
  boosts('Boosts', 'boost', studio: true),
  campaigns('Campaigns', 'campaign', studio: true),
  payouts('Payouts', 'payout', studio: true);

  const _Kind(this.label, this.match, {this.studio = false});
  final String label;
  final String? match;

  /// Creator-side money. Never shown here; see the note above.
  final bool studio;
}

enum _Status {
  all('All', null),
  success('Paid', 'success'),
  pending('Pending', 'pending'),
  failed('Failed', 'failed');

  const _Status(this.label, this.match);
  final String label;
  final String? match;
}

class _PaymentsPageState extends State<PaymentsPage> {
  late final PaymentsApi _api = widget._api ?? PaymentsApi();

  List<PaymentRecord> _all = const [];
  bool _loading = true;
  _Kind _kind = _Kind.all;
  _Status _status = _Status.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await _api.fetch();
    if (!mounted) return;
    setState(() {
      _all = records;
      _loading = false;
    });
  }

  /// Studio money, dropped before anything else looks at the list.
  ///
  /// The chips alone were not enough: with no Boosts chip on screen, `All`
  /// still meant every row the two services returned, so a creator's boosts
  /// appeared in the list under a filter bar that gave no way to take them
  /// out again.
  List<PaymentRecord> get _mine => [
        for (final r in _all)
          if (!_studioKinds.contains(r.kind)) r
      ];

  static final Set<String> _studioKinds = {
    for (final k in _Kind.values)
      if (k.studio && k.match != null) k.match!,
  };

  List<PaymentRecord> get _visible => [
        for (final r in _mine)
          if ((_kind.match == null ||
                  !_kinds.contains(_kind) ||
                  r.kind == _kind.match) &&
              (_status.match == null || r.status == _status.match))
            r
      ];

  /// Only the kinds this account actually has, plus All.
  ///
  /// Two filters at once. The chips follow the *history*, because six chips
  /// where two apply is a bar that mostly filters to nothing — somebody who
  /// has only ever bought photos gets All and Purchases and no dead controls.
  ///
  /// And they follow what this screen is *for*: studio money is excluded
  /// whether or not the account has any, so a creator who opens this by some
  /// other route still sees only the spending side. Bookings stay — a deposit
  /// on a photographer is an explorer paying for something, and hiding money
  /// somebody actually spent because a chip felt like one too many is the
  /// wrong trade.
  List<_Kind> get _kinds {
    final present = {for (final r in _mine) r.kind};
    return [
      _Kind.all,
      for (final k in _Kind.values)
        if (!k.studio && k.match != null && present.contains(k.match)) k,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final rows = _visible;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const AppBackButton(),
        title: Text(
          'Payments',
          style: TextStyle(
            color: ext.greetingColor,
            fontFamily: AppTypography.displayFontFamily,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const AppLoadingIndicator()
          : RefreshIndicator(
              color: ext.accentGold,
              onRefresh: _load,
              child: Column(
                children: [
                  // Two axes, and they are not peers: the first says what kind
                  // of payment, the second narrows that to a state. Drawn the
                  // same size and weight they read as one bank of eight
                  // buttons, which is what this screen looked like — hence the
                  // primary/secondary pair rather than two identical rows.
                  if (_kinds.length > 1) ...[
                    SizedBox(height: AppSpacing.sm.h),
                    AppFilterRow(
                      labels: [for (final k in _kinds) k.label],
                      // A refresh can take the selected kind away — the last
                      // boost is refunded, and "Boosts" stops existing. Fall
                      // back to All rather than leaving a filter applied that
                      // no chip is showing as on.
                      selected:
                          _kinds.contains(_kind) ? _kinds.indexOf(_kind) : 0,
                      onSelect: (i) => setState(() => _kind = _kinds[i]),
                    ),
                  ],
                  if (_mine.isNotEmpty) ...[
                    SizedBox(height: AppSpacing.sm.h),
                    AppFilterRow(
                      labels: [for (final s in _Status.values) s.label],
                      selected: _Status.values.indexOf(_status),
                      onSelect: (i) =>
                          setState(() => _status = _Status.values[i]),
                      style: AppFilterRowStyle.secondary,
                    ),
                  ],
                  SizedBox(height: AppSpacing.sm.h),
                  Expanded(
                    child: rows.isEmpty
                        // Always scrollable, or pull-to-refresh is unreachable
                        // on the one screen state that most needs it.
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: 80.h),
                              AppEmptyState(
                                icon: Icons.receipt_long_outlined,
                                message: _mine.isEmpty
                                    ? 'No payments yet'
                                    : 'Nothing matches those filters',
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                                AppSpacing.lg.w,
                                AppSpacing.sm.h,
                                AppSpacing.lg.w,
                                AppSpacing.xxxl.h),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: AppSpacing.sm.h),
                            itemBuilder: (context, i) => _PaymentTile(
                              record: rows[i],
                              ext: ext,
                              onTap: () =>
                                  PaymentReceiptSheet.show(context, rows[i]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── One payment ───────────────────────────────────────────────────────────────

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.record,
    required this.ext,
    required this.onTap,
  });

  final PaymentRecord record;
  final AppThemeExtension ext;

  /// Opens the receipt. Every row has one — including a failed payment, which
  /// is the row somebody is most likely to need to show to somebody else.
  final VoidCallback onTap;

  /// Paid, waiting, or not gone through — said in a colour as well as a word,
  /// because the colour is what somebody scanning the list actually reads.
  (Color, String) get _state => switch (record.status) {
        'success' => (ext.accentGold, 'Paid'),
        'failed' => (ext.errorRed, 'Failed'),
        _ => (ext.searchHintColor, 'Pending'),
      };

  String get _amount {
    final sign = record.isIncoming ? '+' : '';
    return '$sign${record.currency} ${record.amount.toStringAsFixed(2)}';
  }

  String? get _when {
    final date = record.date;
    if (date == null) return null;
    final local = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final (stateColor, stateLabel) = _state;
    final detail = [
      if (record.subtitle != null && record.subtitle!.isNotEmpty)
        record.subtitle!,
      if (_when != null) _when!,
    ].join(' · ');

    return Material(
      key: ValueKey('payment-${record.id}'),
      color: ext.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.md.r),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      record.title,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (detail.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        detail,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _amount,
                    style: TextStyle(
                      // Money coming in is the exception on this screen, so it is
                      // the one that gets a colour.
                      color: record.isIncoming
                          ? ext.accentGold
                          : ext.greetingColor,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    stateLabel,
                    style: TextStyle(
                      color: stateColor,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
