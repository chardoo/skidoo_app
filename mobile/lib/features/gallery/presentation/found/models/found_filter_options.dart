import 'package:flutter/foundation.dart' show immutable;
import 'package:skidoo_app/features/gallery/presentation/found/models/found_filters.dart';

/// One selectable chip in the filter sheet, with the number of photos it would
/// match.
@immutable
class FoundFilterOption {
  const FoundFilterOption({
    required this.id,
    required this.label,
    required this.count,
    this.avatarUrl = '',
  });

  /// Api value for date/visibility chips; the entity id for
  /// photographer/event chips.
  final String id;
  final String label;
  final int count;
  final String avatarUrl;
}

/// Response of `GET /client/my-photos/filters` — the chips to render plus the
/// counts behind them.
///
/// The server computes these against the *current* selection, which is why the
/// sheet re-requests as the user toggles: `matchingCount` drives the
/// "Show N photos" button, and the photographer/event lists honour the date +
/// visibility selection while ignoring each other's, so toggling one chip
/// never empties the other list.
@immutable
class FoundFilterOptions {
  const FoundFilterOptions({
    this.matchingCount = 0,
    this.totalCount = 0,
    this.dateRanges = const [],
    this.visibility = const [],
    this.photographers = const [],
    this.events = const [],
  });

  /// Photos matching the selection the request was made with.
  final int matchingCount;

  /// Photos ignoring all filters — the headline "48 found".
  final int totalCount;

  final List<FoundFilterOption> dateRanges;
  final List<FoundFilterOption> visibility;
  final List<FoundFilterOption> photographers;
  final List<FoundFilterOption> events;

  static const empty = FoundFilterOptions();

  /// The count the server reported for [id] within [group], or null when the
  /// group doesn't mention it — a chip the client renders from a fixed list
  /// ("Custom range") has no server-side facet behind it.
  static int? countIn(List<FoundFilterOption> group, String id) {
    for (final option in group) {
      if (option.id == id) return option.count;
    }
    return null;
  }

  factory FoundFilterOptions.fromJson(Map<String, dynamic> json) {
    return FoundFilterOptions(
      matchingCount: _int(json['matchingCount']) ?? 0,
      totalCount: _int(json['totalCount']) ?? 0,
      dateRanges: _parse(
        json['dateRanges'],
        idKey: 'value',
        // The API sends date/visibility chips as bare api values; the human
        // label lives in the enum so the two can't drift.
        labelOf: (m) =>
            FoundDateRangeApi.fromApi(m['value']?.toString() ?? '').label,
      ),
      visibility: _parse(
        json['visibility'],
        idKey: 'value',
        labelOf: (m) =>
            FoundVisibilityApi.fromApi(m['value']?.toString() ?? '').label,
      ),
      photographers: _parse(
        json['photographers'],
        idKey: 'id',
        labelOf: (m) => m['name']?.toString() ?? '',
      ),
      events: _parse(
        json['events'],
        idKey: 'id',
        labelOf: (m) => m['eventName']?.toString() ?? '',
      ),
    );
  }

  static List<FoundFilterOption> _parse(
    dynamic raw, {
    required String idKey,
    required String Function(Map<String, dynamic>) labelOf,
  }) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((m) => FoundFilterOption(
              id: m[idKey]?.toString() ?? '',
              label: labelOf(m),
              count: _int(m['count']) ?? 0,
              avatarUrl: m['profile_url']?.toString() ?? '',
            ))
        .where((o) => o.id.isNotEmpty && o.label.isNotEmpty)
        .toList(growable: false);
  }

  static int? _int(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
