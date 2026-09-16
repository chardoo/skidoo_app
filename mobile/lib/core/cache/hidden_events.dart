import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Albums this reader has hidden, for every screen that shows albums.
///
/// "Hide event" promises "You won't see this event again", and it was kept by
/// whichever widget happened to be on screen when it was tapped. The discover
/// feed kept it properly — a set in [DiscoveryBloc], persisted, and re-applied
/// wherever events entered its state. The Following feed kept it by calling
/// `removeWhere` on its own list and nothing else: the card went, the next
/// fetch put it straight back, and the promise was broken on the one screen
/// most likely to show the same photographer again.
///
/// Two lists cannot each own the same decision. Hiding is a fact about the
/// reader, not about a screen, so it lives in one place and every surface
/// filters through it.
///
/// **Still the device's own memory, deliberately.** The obvious better answer
/// is the server — hiding would then survive a reinstall and reach every
/// device. But the only server-side notion of "I don't want this" today is the
/// dislike reaction, and that is a different thing wearing the same coat: it
/// feeds `Event.dislikes`, a number the photographer is shown. Hiding a wedding
/// because you have seen it four times must not mark the wedding down. Until
/// hiding has a row of its own, the device is the honest place for it.
///
/// The key is the one [DiscoveryBloc] already wrote, so hides made before this
/// existed are still here.
class HiddenEvents {
  HiddenEvents._();

  static const _key = 'discovery_hidden_event_ids';

  /// Null until the first load. Callers get an empty set meanwhile, which is
  /// the safe direction to be wrong in: a hidden card shown once more is a
  /// smaller failure than an unhidden feed emptied by a half-read set.
  static Set<String>? _ids;

  /// What is hidden right now. Empty before [load] has finished.
  static Set<String> get ids => _ids ?? const <String>{};

  static bool isHidden(String eventId) => ids.contains(eventId);

  /// Read the stored set. Safe to call repeatedly — the disk read happens once.
  ///
  /// Never throws: a screen that cannot read this should draw an unfiltered
  /// feed, not fail to draw one.
  static Future<Set<String>> load() async {
    final cached = _ids;
    if (cached != null) return cached;
    try {
      final prefs = await SharedPreferences.getInstance();
      return _ids = (prefs.getStringList(_key) ?? const <String>[]).toSet();
    } catch (e) {
      debugPrint('[HiddenEvents] could not read: $e');
      return _ids = <String>{};
    }
  }

  /// Hide an album everywhere, from now on.
  static Future<void> hide(String eventId) async {
    if (eventId.isEmpty) return;
    await _write({...await load(), eventId});
  }

  /// Put one back — what Undo does once the snackbar has gone.
  static Future<void> unhide(String eventId) async {
    final current = await load();
    if (!current.contains(eventId)) return;
    await _write({...current}..remove(eventId));
  }

  /// Replace the whole set. For [DiscoveryBloc], which keeps its own copy in
  /// bloc state so its list rebuilds, and hands the durable half here.
  static Future<void> replace(Set<String> ids) => _write({...ids});

  static Future<void> _write(Set<String> next) async {
    _ids = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, next.toList());
    } catch (e) {
      // The in-memory set still holds, so hiding works for this session and
      // is forgotten on restart. Worth a line in the log; not worth failing a
      // tap over.
      debugPrint('[HiddenEvents] could not persist: $e');
    }
  }

  /// [items] minus anything hidden.
  ///
  /// Applied wherever albums enter a list, not only where one was tapped — a
  /// filter that runs at the tap and nowhere else is exactly the bug this
  /// class exists to end.
  static List<T> filter<T>(List<T> items, String Function(T) idOf) {
    final hidden = ids;
    if (hidden.isEmpty) return items;
    return items.where((e) => !hidden.contains(idOf(e))).toList();
  }

  @visibleForTesting
  static void resetForTest([Set<String>? ids]) => _ids = ids;
}
