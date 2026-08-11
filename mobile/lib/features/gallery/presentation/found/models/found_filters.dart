import 'package:flutter/material.dart' show DateTimeRange, immutable;

/// Date buckets offered by the Found filter sheet, mirroring the API's
/// `dateRange` values. [all] is the "no date filter" state — it has no chip of
/// its own; it's what you get by de-selecting whichever chip was active.
///
/// The server matches on the photo's **shoot date** (`photoDate`), not on when
/// the face was recognised.
enum FoundDateRange { all, thisMonth, lastThreeMonths, custom }

extension FoundDateRangeApi on FoundDateRange {
  String get apiValue => switch (this) {
        FoundDateRange.all => 'all',
        FoundDateRange.thisMonth => 'this_month',
        FoundDateRange.lastThreeMonths => 'last_3_months',
        FoundDateRange.custom => 'custom',
      };

  String get label => switch (this) {
        FoundDateRange.all => 'Any time',
        FoundDateRange.thisMonth => 'This month',
        FoundDateRange.lastThreeMonths => 'Last 3 months',
        FoundDateRange.custom => 'Custom range',
      };

  static FoundDateRange fromApi(String value) => switch (value) {
        'this_month' => FoundDateRange.thisMonth,
        'last_3_months' => FoundDateRange.lastThreeMonths,
        'custom' => FoundDateRange.custom,
        _ => FoundDateRange.all,
      };
}

/// Public/private visibility. [all] is the default and is rendered as its own
/// "All" chip, per the design.
enum FoundVisibility { all, public, private }

extension FoundVisibilityApi on FoundVisibility {
  String get apiValue => name;

  String get label => switch (this) {
        FoundVisibility.all => 'All',
        FoundVisibility.public => 'Public',
        FoundVisibility.private => 'Private',
      };

  static FoundVisibility fromApi(String value) => switch (value) {
        'public' => FoundVisibility.public,
        'private' => FoundVisibility.private,
        _ => FoundVisibility.all,
      };
}

/// Which answers count as a match.
///
/// [confirmed] is what "my photos" means and stays the default. [all] is for
/// the review screens: a scan result is about to ask *which of these are not
/// you*, and it cannot ask that about matches the server withheld because they
/// were unanswered. Rejected matches come back under none of them.
enum FoundMatchStatus { confirmed, pending, all }

extension FoundMatchStatusApi on FoundMatchStatus {
  String get apiValue => name;
}

/// The Found tab's filter selection.
///
/// This is a *query*, not a predicate: filtering happens server-side on both
/// `/client/my-photos` and `/client/my-photos/filters`, so the job here is to
/// serialize to query parameters ([toQueryParameters]) rather than to test
/// photos locally. Client-side filtering would only ever see the pages already
/// scrolled in, which is why it isn't done that way.
@immutable
class FoundFilters {
  const FoundFilters({
    this.dateRange = FoundDateRange.all,
    this.customRange,
    this.visibility = FoundVisibility.all,
    this.status = FoundMatchStatus.confirmed,
    this.photographerIds = const <String>{},
    this.eventIds = const <String>{},
  });

  final FoundDateRange dateRange;

  /// Only meaningful when [dateRange] is [FoundDateRange.custom]; sent as the
  /// inclusive `startDate`/`endDate` pair.
  final DateTimeRange? customRange;

  final FoundVisibility visibility;

  /// Which answers count. Not part of [activeCount] — it is a property of the
  /// screen asking, not a filter the user set.
  final FoundMatchStatus status;

  /// Photographer ids to keep. Empty = every photographer.
  final Set<String> photographerIds;

  /// Event ids to keep — used for the "+N" drill-down into one album, and for
  /// a scanned event. Either an id or an access code: the server resolves both,
  /// which matters because a QR carries the code.
  final Set<String> eventIds;

  static const none = FoundFilters();

  /// Number of filter *groups* that deviate from their default — the number
  /// shown in the badge on the Filters button, so picking three photographers
  /// still counts as one. [eventIds] is excluded: it's a navigation
  /// constraint, not something the user set in the sheet.
  int get activeCount =>
      (dateRange != FoundDateRange.all ? 1 : 0) +
      (visibility != FoundVisibility.all ? 1 : 0) +
      (photographerIds.isEmpty ? 0 : 1);

  bool get isActive => activeCount > 0;

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Query parameters for either endpoint. Defaults are omitted rather than
  /// sent explicitly, keeping URLs (and the server's cache keys) clean.
  Map<String, dynamic> toQueryParameters() {
    return {
      if (dateRange != FoundDateRange.all) 'dateRange': dateRange.apiValue,
      if (dateRange == FoundDateRange.custom && customRange != null) ...{
        'startDate': _day(customRange!.start),
        'endDate': _day(customRange!.end),
      },
      if (visibility != FoundVisibility.all) 'visibility': visibility.apiValue,
      if (status != FoundMatchStatus.confirmed) 'status': status.apiValue,
      // Repeatable params — Dio's default ListFormat emits one key per value,
      // which is the `?photographerId=a&photographerId=b` form.
      if (photographerIds.isNotEmpty)
        'photographerId': photographerIds.toList(growable: false),
      if (eventIds.isNotEmpty) 'eventId': eventIds.toList(growable: false),
    };
  }

  FoundFilters copyWith({
    FoundDateRange? dateRange,
    DateTimeRange? customRange,
    bool clearCustomRange = false,
    FoundVisibility? visibility,
    FoundMatchStatus? status,
    Set<String>? photographerIds,
    Set<String>? eventIds,
  }) {
    return FoundFilters(
      dateRange: dateRange ?? this.dateRange,
      customRange: clearCustomRange ? null : (customRange ?? this.customRange),
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      photographerIds: photographerIds ?? this.photographerIds,
      eventIds: eventIds ?? this.eventIds,
    );
  }

  /// Tapping the already-selected date chip clears the date filter.
  FoundFilters toggleDate(FoundDateRange range, {DateTimeRange? custom}) {
    if (dateRange == range && range != FoundDateRange.custom) {
      return copyWith(dateRange: FoundDateRange.all, clearCustomRange: true);
    }
    return copyWith(dateRange: range, customRange: custom);
  }

  FoundFilters togglePhotographer(String id) {
    final next = Set<String>.from(photographerIds);
    if (!next.remove(id)) next.add(id);
    return copyWith(photographerIds: next);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FoundFilters &&
          other.dateRange == dateRange &&
          other.customRange == customRange &&
          other.visibility == visibility &&
          other.status == status &&
          _sameIds(other.photographerIds, photographerIds) &&
          _sameIds(other.eventIds, eventIds);

  static bool _sameIds(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => Object.hash(
        dateRange,
        customRange,
        visibility,
        status,
        Object.hashAllUnordered(photographerIds),
        Object.hashAllUnordered(eventIds),
      );
}
