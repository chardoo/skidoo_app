/// Which rung a connection can afford.
///
/// A fixed rung bets that every reader has the same connection. The feed rung
/// is ~204 KB — under a fifth of a second on wifi, over half a second on a
/// 3 Mbps mobile link, which in Ghana is the common case. The 640 rung is
/// ~59 KB and in a phone-width card the difference is hard to find. This is
/// the arithmetic that decides, and it is the part worth pinning.
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/utils/network_quality.dart';

/// Throughput for a link of `mbps`, in bytes per second.
double _mbps(double mbps) => mbps * 1000 * 1000 / 8;

void main() {
  setUp(NetworkQuality.resetForTest);

  group('choosing a rung for a connection', () {
    test('good wifi affords the full feed rung', () {
      expect(NetworkQuality.capFor(_mbps(20), current: 1080), 1080);
    });

    test('a 3 Mbps mobile link drops to 640', () {
      // 204 KB at 3 Mbps is ~0.54 s, past the 400 ms budget. 59 KB is ~0.16 s.
      expect(NetworkQuality.capFor(_mbps(3), current: 1080), 640);
    });

    test('a very slow link drops to the smallest rung', () {
      expect(NetworkQuality.capFor(_mbps(0.5), current: 1080), 320);
    });

    test('slower than the smallest rung still gets the smallest rung', () {
      // There is nothing below it, and the original would be far worse.
      expect(NetworkQuality.capFor(_mbps(0.05), current: 320), 320);
    });
  });

  group('the answer has to be stable', () {
    test('moving up a tier demands headroom', () {
      // Right at the 1080 threshold, a reader already on 640 stays there: a
      // tier that flips on the boundary changes the URL the feed asks for, so
      // the card warmed at one size is requested at another and the warm-up is
      // thrown away.
      final justEnough = 203744 / 0.4; // exactly the 1080 budget
      expect(NetworkQuality.capFor(justEnough, current: 640), 640);
      expect(NetworkQuality.capFor(justEnough * 1.3, current: 640), 1080);
    });

    test('staying put needs no headroom', () {
      final justEnough = 203744 / 0.4;
      expect(NetworkQuality.capFor(justEnough, current: 1080), 1080);
    });
  });

  group('what it learns from', () {
    test('starts optimistic, before anything is measured', () {
      // The first cards of a session have no samples, and opening small would
      // make a good connection look bad for the cards a reader judges by.
      expect(NetworkQuality.instance.feedMaxPhysicalWidth, 1080);
      expect(NetworkQuality.instance.bytesPerSecond, isNull);
    });

    test('a slow link is learnt from real downloads', () {
      // 204 KB taking a second and a half is about 1 Mbps.
      for (var i = 0; i < 12; i++) {
        NetworkQuality.instance.record(
          bytes: 203744,
          elapsed: const Duration(milliseconds: 1500),
        );
      }
      expect(NetworkQuality.instance.feedMaxPhysicalWidth, lessThan(1080));
    });

    test('one unlucky fetch does not drop everybody a tier', () {
      // A single slow request is usually a slow *object* — a cold edge, a
      // retry — not a slow connection.
      for (var i = 0; i < 10; i++) {
        NetworkQuality.instance.record(
          bytes: 203744, elapsed: const Duration(milliseconds: 100));
      }
      NetworkQuality.instance.record(
          bytes: 203744, elapsed: const Duration(seconds: 4));
      expect(NetworkQuality.instance.feedMaxPhysicalWidth, 1080);
    });

    test('a tiny file teaches nothing — it measures latency, not bandwidth', () {
      // 2 KB in 300 ms is almost all round trip; taken at face value it reads
      // as 7 KB/s and would drop a fast connection to the smallest rung.
      NetworkQuality.instance.record(
          bytes: 2048, elapsed: const Duration(milliseconds: 300));
      expect(NetworkQuality.instance.bytesPerSecond, isNull);
      expect(NetworkQuality.instance.feedMaxPhysicalWidth, 1080);
    });

    test('a zero duration is ignored rather than dividing by it', () {
      NetworkQuality.instance.record(bytes: 203744, elapsed: Duration.zero);
      expect(NetworkQuality.instance.bytesPerSecond, isNull);
    });
  });
}
