import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/location/data/models/place.dart';
import 'package:jperg_app/features/location/data/repositories/location_repository.dart';

/// Picking somewhere: a country first, then a town inside it.
///
/// Country first because the country is the part that matters. It is the hard
/// filter — content aimed at Ghana is never served outside Ghana — while the
/// town only decides how near something ranks. Asking for the town first would
/// put the optional half of the answer in front of the necessary one, and there
/// is no useful worldwide list of towns to search before you know which country
/// you mean.
///
/// "Anywhere in <country>" is offered at the top of the second step and is a
/// real answer, not a way out of it: somebody advertising nationally should not
/// have to name a city they do not mean.
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key, this.title, this.repo});

  final String? title;

  /// Injectable so tests can drive the sheet without a network.
  final LocationRepository? repo;

  /// Opens the picker and returns the chosen place, or null if it was
  /// dismissed. Scrollable because the second step is a search results list
  /// and the keyboard takes half the screen.
  ///
  /// [repo] is passed on so a caller that already has one — the mismatch
  /// prompt, or a test — keeps using it rather than having a second built
  /// underneath it.
  static Future<Place?> show(
    BuildContext context, {
    String? title,
    LocationRepository? repo,
  }) {
    return showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerSheet(title: title, repo: repo),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  late final LocationRepository _repo = widget.repo ?? LocationRepository();
  final _searchCtrl = TextEditingController();

  List<Place> _countries = const [];
  List<Place> _results = const [];
  Place? _country;

  bool _loading = true;
  bool _searching = false;

  /// The type-ahead's debounce. Long enough that typing a word is one request
  /// rather than five, short enough not to feel like lag.
  Timer? _debounce;

  /// Which search the results on screen belong to. Answers can come back out
  /// of order — "acc" is slower than "accra" often enough to matter — and
  /// without this a stale reply overwrites a fresher one.
  int _queryToken = 0;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    final countries = await _repo.countries();
    if (!mounted) return;
    setState(() {
      _countries = countries;
      _loading = false;
    });
  }

  void _pickCountry(Place country) {
    setState(() {
      _country = country;
      _results = const [];
      _searchCtrl.clear();
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    if (query.length < LocationRepository.minQuery) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 320), () => _run(query));
  }

  Future<void> _run(String query) async {
    final token = ++_queryToken;
    final places = await _repo.search(query, countryCode: _country?.countryCode);
    if (!mounted || token != _queryToken) return;
    setState(() {
      _results = places;
      _searching = false;
    });
  }

  /// The country as a whole — gates, does not rank.
  void _chooseWholeCountry() {
    final country = _country;
    if (country == null) return;
    Navigator.of(context).pop(Place(
      countryCode: country.countryCode,
      country: country.country,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      height: MediaQuery.sizeOf(context).height * 0.82,
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.only(bottom: bottom),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              _grabHandle(ext),
              _header(ext),
              SizedBox(height: AppSpacing.sm.h),
              Expanded(
                child: _loading
                    ? const AppLoadingIndicator()
                    : _country == null
                        ? _CountryStep(
                            countries: _countries,
                            ext: ext,
                            onPick: _pickCountry,
                          )
                        : _PlaceStep(
                            country: _country!,
                            controller: _searchCtrl,
                            results: _results,
                            searching: _searching,
                            ext: ext,
                            onQueryChanged: _onQueryChanged,
                            onWholeCountry: _chooseWholeCountry,
                            onPick: (place) =>
                                Navigator.of(context).pop(place),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _grabHandle(AppThemeExtension ext) => Container(
        margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
        width: 36.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: ext.searchHintColor.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(2.r),
        ),
      );

  Widget _header(AppThemeExtension ext) {
    final inCountry = _country != null;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Row(
        children: [
          if (inCountry)
            Semantics(
              button: true,
              label: 'Back to countries',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _country = null;
                  _results = const [];
                  _searchCtrl.clear();
                }),
                child: Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm.w),
                  child: Icon(Icons.arrow_back_rounded,
                      color: ext.greetingColor, size: 20.r),
                ),
              ),
            ),
          Expanded(
            child: Text(
              inCountry
                  ? (_country!.country ?? _country!.countryCode)
                  : (widget.title ?? 'Choose a location'),
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step one: the country ───────────────────────────────────────────────────

class _CountryStep extends StatefulWidget {
  const _CountryStep({
    required this.countries,
    required this.ext,
    required this.onPick,
  });

  final List<Place> countries;
  final AppThemeExtension ext;
  final ValueChanged<Place> onPick;

  @override
  State<_CountryStep> createState() => _CountryStepState();
}

class _CountryStepState extends State<_CountryStep> {
  final _filterCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  /// Filtered on the device. All two hundred and forty-nine arrive in one
  /// response and never change, so asking a server to narrow them would be a
  /// round trip to do what a `where` does instantly.
  List<Place> get _visible {
    if (_filter.isEmpty) return widget.countries;
    final needle = _filter.toLowerCase();
    return [
      for (final c in widget.countries)
        if ((c.country ?? '').toLowerCase().contains(needle) ||
            c.countryCode.toLowerCase() == needle)
          c,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final visible = _visible;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          child: AppTextField(
            controller: _filterCtrl,
            hint: 'Search countries',
            prefixIcon: Icons.search_rounded,
            dense: true,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _filter = v.trim()),
          ),
        ),
        SizedBox(height: AppSpacing.sm.h),
        Expanded(
          child: visible.isEmpty
              ? const AppEmptyState(
                  icon: Icons.public_off_rounded,
                  message: 'No countries match that',
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final country = visible[i];
                    return ListTile(
                      onTap: () => widget.onPick(country),
                      title: Text(
                        country.country ?? country.countryCode,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: ext.searchHintColor, size: 20.r),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Step two: the town ──────────────────────────────────────────────────────

class _PlaceStep extends StatelessWidget {
  const _PlaceStep({
    required this.country,
    required this.controller,
    required this.results,
    required this.searching,
    required this.ext,
    required this.onQueryChanged,
    required this.onWholeCountry,
    required this.onPick,
  });

  final Place country;
  final TextEditingController controller;
  final List<Place> results;
  final bool searching;
  final AppThemeExtension ext;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onWholeCountry;
  final ValueChanged<Place> onPick;

  @override
  Widget build(BuildContext context) {
    final typed = controller.text.trim();
    final tooShort = typed.length < LocationRepository.minQuery;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          child: AppTextField(
            controller: controller,
            hint: 'Search a town or city',
            prefixIcon: Icons.search_rounded,
            dense: true,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: onQueryChanged,
          ),
        ),
        SizedBox(height: AppSpacing.sm.h),
        _WholeCountryTile(country: country, ext: ext, onTap: onWholeCountry),
        Divider(
          height: AppSpacing.lg.h,
          color: ext.searchHintColor.withValues(alpha: 0.15),
        ),
        Expanded(
          child: Builder(builder: (_) {
            if (searching) return const AppLoadingIndicator();
            if (tooShort) {
              return _Hint(
                ext: ext,
                text: 'Type at least ${LocationRepository.minQuery} letters to '
                    'search towns and cities in '
                    '${country.country ?? country.countryCode}.',
              );
            }
            if (results.isEmpty) {
              return _Hint(
                ext: ext,
                text: 'Nothing matched "$typed". Check the spelling, or use '
                    'the whole country above.',
              );
            }
            return ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: results.length,
              itemBuilder: (_, i) {
                final place = results[i];
                return ListTile(
                  onTap: () => onPick(place),
                  title: Text(
                    place.name ?? '',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    place.subtitle,
                    style: TextStyle(
                        color: ext.searchHintColor, fontSize: 12.sp),
                  ),
                  trailing: Icon(Icons.add_rounded,
                      color: ext.accentGold, size: 20.r),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}

class _WholeCountryTile extends StatelessWidget {
  const _WholeCountryTile({
    required this.country,
    required this.ext,
    required this.onTap,
  });

  final Place country;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38.w,
        height: 38.w,
        decoration: BoxDecoration(
          color: ext.accentGold.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10.r),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.public_rounded, color: ext.accentGold, size: 20.r),
      ),
      title: Text(
        'Anywhere in ${country.country ?? country.countryCode}',
        style: TextStyle(
          color: ext.greetingColor,
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        'Reaches the whole country',
        style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.ext, required this.text});

  final AppThemeExtension ext;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl.w, vertical: AppSpacing.xxl.h),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 13.sp,
            height: 1.5,
          ),
        ),
      );
}

// ── The chips a form shows for what has been picked ─────────────────────────

/// The selected places, with a way to add and remove them.
///
/// Shared by the request form and the campaign wizard so the two cannot drift
/// into offering different things — which is exactly what happened to the old
/// hardcoded city list, copied into the wizard and the edit form separately.
class LocationChips extends StatelessWidget {
  const LocationChips({
    super.key,
    required this.places,
    required this.onAdd,
    required this.onRemove,
    this.emptyLabel = 'Everywhere',
  });

  final List<Place> places;
  final VoidCallback onAdd;
  final ValueChanged<Place> onRemove;

  /// What no targeting means. Said plainly, because an empty row reads as
  /// something not yet filled in rather than as a deliberate choice.
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (places.isEmpty)
          Text(
            emptyLabel,
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
          ),
        for (final place in places)
          Container(
            padding: EdgeInsets.only(
                left: AppSpacing.md.w, right: 6.w, top: 6.h, bottom: 6.h),
            decoration: BoxDecoration(
              color: ext.accentGold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xl.r),
              border: Border.all(
                  color: ext.accentGold.withValues(alpha: 0.5), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  place.label,
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(width: 4.w),
                Semantics(
                  button: true,
                  label: 'Remove ${place.label}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onRemove(place),
                    child: Icon(Icons.close_rounded,
                        size: 14.r, color: ext.accentGold),
                  ),
                ),
              ],
            ),
          ),
        Semantics(
          button: true,
          label: 'Add a location',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAdd,
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w, vertical: 7.h),
              decoration: BoxDecoration(
                color: ext.searchFieldFill,
                borderRadius: BorderRadius.circular(AppRadius.xl.r),
                border: Border.all(
                  color: ext.searchHintColor.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded,
                      size: 14.r, color: ext.searchHintColor),
                  SizedBox(width: 4.w),
                  Text(
                    places.isEmpty ? 'Add a location' : 'Add another',
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
