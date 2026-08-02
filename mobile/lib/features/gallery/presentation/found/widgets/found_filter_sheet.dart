import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_button.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/gallery/domain/usecases/get_found_photos_usecase.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filter_options.dart';
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filters.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_filter_chip.dart';
import 'package:skidoo_app/core/common/widgets/app_drag_handle.dart';

/// Bottom sheet holding the Found tab's date / visibility / photographer
/// filters.
///
/// Both the chips and the counts come from `GET /client/my-photos/filters`,
/// re-requested (debounced) on every toggle: the server returns the
/// `matchingCount` behind the "Show N photos" CTA, and recomputes the
/// photographer list against the current date+visibility selection so
/// toggling one chip never empties the other list.
///
/// Selections are edited on a *draft* copy and only handed back when the user
/// confirms with the CTA, so dismissing the sheet leaves the grid untouched.
class FoundFilterSheet extends StatefulWidget {
  const FoundFilterSheet({
    super.key,
    required this.initial,
    this.isWeb = false,
  });

  final FoundFilters initial;

  /// Renders as a centred card instead of a bottom-anchored sheet.
  final bool isWeb;

  /// Opens the sheet and resolves to the filters the user confirmed, or null
  /// if they dismissed it.
  static Future<FoundFilters?> show(
    BuildContext context, {
    required FoundFilters initial,
  }) {
    if (kIsWeb) {
      return showDialog<FoundFilters>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.55),
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: webWrap(
            FoundFilterSheet(initial: initial, isWeb: true),
            backgroundColor: Colors.transparent,
            width: kWebColumnWidth,
          ),
        ),
      );
    }
    return showModalBottomSheet<FoundFilters>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => FoundFilterSheet(initial: initial),
    );
  }

  @override
  State<FoundFilterSheet> createState() => _FoundFilterSheetState();
}

class _FoundFilterSheetState extends State<FoundFilterSheet> {
  late FoundFilters _draft = widget.initial;

  FoundFilterOptions _options = FoundFilterOptions.empty;
  bool _loading = true;
  String? _error;

  Timer? _debounce;

  /// Guards against an earlier, slower response overwriting a later one.
  int _requestId = 0;

  /// The selection [_options] was computed for. The counts on screen are only
  /// truthful while this equals [_draft] — see [_countIsCurrent].
  FoundFilters? _countFor;

  /// Photographer names kept by id across refetches.
  ///
  /// The server recomputes the photographer list against the date/visibility
  /// selection, so a photographer the user has *selected* can drop out of the
  /// list. Without this, their chip would vanish while still filtering, and
  /// there'd be no way to switch it back off.
  final _nameById = <String, String>{};

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final id = ++_requestId;
    // Capture what this request is for — `_draft` can move on while it's in
    // flight, and the response is only valid for the selection it was sent
    // with.
    final requested = _draft;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await sl<GetFoundPhotosUseCase>().filterOptions(requested);
      if (!mounted || id != _requestId) return;
      setState(() {
        _options = options;
        _countFor = requested;
        for (final p in options.photographers) {
          _nameById[p.id] = p.label;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = e.toString();
        // The stale counts must not survive a failure — nothing on screen is
        // known to match the selection any more.
        _countFor = null;
        _loading = false;
      });
    }
  }

  /// Toggling chips is cheap locally but costs a round-trip for the counts,
  /// so the refetch trails the taps rather than firing on each one.
  ///
  /// [_loading] is raised here rather than in [_fetch] so it covers the debounce
  /// window too. Otherwise the numbers on screen vanish the instant a chip is
  /// tapped — they belong to the old selection — while the progress hairline
  /// stays dark for 250 ms, which reads as a glitch rather than as a count on
  /// its way.
  void _update(FoundFilters next) {
    setState(() {
      _draft = next;
      _loading = true;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _fetch);
  }

  bool get _canApply => _draft.isActive || _draft != widget.initial;

  /// Whether the count in hand was computed for exactly the current draft.
  bool get _countIsCurrent => _countFor == _draft;

  /// `matchingCount` comes straight from `GET /client/my-photos/filters` — it
  /// is never derived on the client, because the client only holds the pages
  /// it has scrolled in and would undercount everything past them.
  ///
  /// The consequence is that the number lags the taps by a round trip, and a
  /// number that doesn't match what the chips show is worse than no number:
  /// it reads as simply wrong. So while the request is in flight the label
  /// drops back to "Show photos" rather than showing the previous selection's
  /// total.
  String get _ctaLabel {
    // Nothing selected: the design's resting/disabled state carries no number.
    if (!_draft.isActive) return _canApply ? 'Show all photos' : 'Show photos';
    if (!_countIsCurrent) return 'Show photos';
    final n = _options.matchingCount;
    return 'Show $n ${n == 1 ? 'photo' : 'photos'}';
  }

  /// Photographer chips to render: the server's current list, plus any
  /// selected photographer the latest response dropped (it's still filtering,
  /// so it has to stay switchable-off). Server order is preserved.
  List<({String id, String label, int count})> get _photographerChips {
    final chips = [
      for (final p in _options.photographers)
        (id: p.id, label: p.label, count: p.count),
    ];
    final shown = chips.map((c) => c.id).toSet();
    for (final id in _draft.photographerIds) {
      if (shown.contains(id)) continue;
      // Dropped from the server's list means it matches nothing under the
      // current date/visibility selection — a count of zero. It stays on
      // screen and stays tappable because it's still applied.
      chips.add((id: id, label: _nameById[id] ?? 'Photographer', count: 0));
    }
    return chips;
  }

  /// Photographer counts are computed against the date/visibility selection, so
  /// they go stale the moment a chip is tapped and are withheld until the
  /// response catches up — same rule as the CTA's number.
  ///
  /// Date and visibility counts are not gated: the server computes those over
  /// the unfiltered set precisely so they hold still while the user
  /// experiments, which makes them true no matter what the draft is.
  int? _contextualCount(int count) => _countIsCurrent ? count : null;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _draft.customRange,
    );
    if (picked == null || !mounted) return;
    _update(_draft.copyWith(
        dateRange: FoundDateRange.custom, customRange: picked));
  }

  void _onDateTap(FoundDateRange range) {
    // "Custom range" always re-opens the picker — including when it's already
    // selected, so the user can adjust the dates. Use "Clear" to drop it.
    if (range == FoundDateRange.custom) {
      _pickCustomRange();
      return;
    }
    _update(_draft.toggleDate(range));
  }

  /// The design pins the sheet to just over half the screen, with the CTA
  /// resting at the bottom and empty space above it rather than the sheet
  /// shrink-wrapping its chips. Content longer than that scrolls.
  static const _heightFactor = 0.52;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: widget.isWeb
          ? null
          : BoxConstraints(
              minHeight: screenHeight * _heightFactor,
              maxHeight: screenHeight * 0.9,
            ),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: widget.isWeb
            ? BorderRadius.circular(AppRadius.xxl.r)
            : BorderRadius.vertical(top: Radius.circular(AppRadius.xxl.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.isWeb) const AppDragHandle(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(AppSpacing.xxl.w, AppSpacing.md.h,
                    AppSpacing.xxl.w, AppSpacing.sm.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filters',
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_draft.isActive)
                          Semantics(
                            button: true,
                            label: 'Clear filters',
                            child: GestureDetector(
                              onTap: () => _update(FoundFilters.none),
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  color: ext.accentGold,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xl.h),
                    if (_error != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
                        child: Text(
                          "Couldn't load filter options. $_error",
                          style: TextStyle(
                              color: ext.errorRed, fontSize: 12.sp),
                        ),
                      ),
                    _FilterGroup(
                      label: 'Date',
                      children: [
                        for (final range in const [
                          FoundDateRange.thisMonth,
                          FoundDateRange.lastThreeMonths,
                          FoundDateRange.custom,
                        ])
                          FoundFilterChip(
                            label: range == FoundDateRange.custom &&
                                    _draft.dateRange == FoundDateRange.custom &&
                                    _draft.customRange != null
                                ? _rangeLabel(_draft.customRange!)
                                : range.label,
                            // "Custom range" has no server-side facet — the
                            // dates aren't known until the picker closes.
                            count: FoundFilterOptions.countIn(
                                _options.dateRanges, range.apiValue),
                            selected: _draft.dateRange == range,
                            onTap: () => _onDateTap(range),
                          ),
                      ],
                    ),
                    _FilterGroup(
                      label: 'Visibility',
                      children: [
                        for (final visibility in FoundVisibility.values)
                          FoundFilterChip(
                            label: visibility.label,
                            count: FoundFilterOptions.countIn(
                                _options.visibility, visibility.apiValue),
                            selected: _draft.visibility == visibility,
                            onTap: () => _update(
                                _draft.copyWith(visibility: visibility)),
                          ),
                      ],
                    ),
                    if (_photographerChips.isNotEmpty)
                      _FilterGroup(
                        label: 'Photographer',
                        children: [
                          for (final chip in _photographerChips)
                            FoundFilterChip(
                              label: chip.label,
                              count: _contextualCount(chip.count),
                              selected:
                                  _draft.photographerIds.contains(chip.id),
                              onTap: () =>
                                  _update(_draft.togglePhotographer(chip.id)),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            // Hairline that marks "the count is catching up with your taps".
            // Without it the label just silently drops its number, which reads
            // as a glitch rather than as work in progress.
            SizedBox(
              height: 2.h,
              child: _loading
                  ? LinearProgressIndicator(
                      minHeight: 2.h,
                      backgroundColor: Colors.transparent,
                      color: ext.accentGold.withValues(alpha: 0.6),
                    )
                  : null,
            ),
            // Centred content-width pill, not a full-bleed bar — see the
            // design's "Show 12 photos".
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.xxl.w, AppSpacing.md.h,
                  AppSpacing.xxl.w, AppSpacing.xl.h),
              child: Center(
                child: AppButton(
                  label: _ctaLabel,
                  height: 52.h,
                  borderRadius: AppRadius.pill,
                  // ~half the screen, as measured off the design, but never
                  // wider than the sheet's content column.
                  width: (MediaQuery.of(context).size.width * 0.52)
                      .clamp(200.0, MediaQuery.of(context).size.width - 48),
                  onPressed: _canApply
                      ? () => Navigator.of(context).pop(_draft)
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _rangeLabel(DateTimeRange range) =>
      '${range.start.day}/${range.start.month} – ${range.end.day}/${range.end.month}';
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.xl.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FoundFilterGroupLabel(label),
          SizedBox(height: AppSpacing.md.h),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            children: children,
          ),
        ],
      ),
    );
  }
}

