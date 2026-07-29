import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/gallery/presentation/found/found_access.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// After "Delete my face data", the Found tab must show "Add your face" the
/// next time it is opened — not the matches it was showing before.
///
/// Two independent mechanisms have to hold for that:
///   1. the flag flips and notifies (deletion made in this app), and
///   2. the tab re-resolves whenever it becomes visible (deletion made
///      anywhere else, or a tab that has been alive since before it happened).
///
/// (2) is driven by TickerMode, which the home page toggles per tab. This
/// exercises that widget contract directly — the full FoundFeed needs the
/// BLoC/service-locator stack to render.
class _FakeAuth extends AuthService {
  _FakeAuth({required this.hasFaces});
  bool hasFaces;

  @override
  Future<String> getToken() async => 'jwt';

  @override
  Future<bool> getHasAddedFaces() async => hasFaces;
}

/// Stand-in for FoundFeed's visibility handling.
class _VisibilityProbe extends StatefulWidget {
  const _VisibilityProbe({required this.onBecameVisible});
  final VoidCallback onBecameVisible;

  @override
  State<_VisibilityProbe> createState() => _VisibilityProbeState();
}

class _VisibilityProbeState extends State<_VisibilityProbe> {
  bool _wasVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_wasVisible) widget.onBecameVisible();
    _wasVisible = visible;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  tearDown(() {
    if (sl.isRegistered<AuthService>()) sl.unregister<AuthService>();
    AuthService.hasAddedFaces.value = false;
  });

  testWidgets('re-checks each time the tab becomes visible', (t) async {
    var checks = 0;

    Widget tree(int selected) => MaterialApp(
          home: IndexedStack(
            index: selected,
            children: [
              TickerMode(
                enabled: selected == 0,
                child: _VisibilityProbe(onBecameVisible: () => checks++),
              ),
              const TickerMode(enabled: true, child: SizedBox.shrink()),
            ],
          ),
        );

    // Land on the other tab: Found is mounted but not visible, so no check.
    await t.pumpWidget(tree(1));
    expect(checks, 0);

    // Open Found → checks.
    await t.pumpWidget(tree(0));
    expect(checks, 1);

    // Leave and come back → checks again. This is the case that matters: the
    // face was deleted while the user was elsewhere.
    await t.pumpWidget(tree(1));
    await t.pumpWidget(tree(0));
    expect(checks, 2);

    // Staying put does not re-check on every rebuild.
    await t.pumpWidget(tree(0));
    expect(checks, 2);
  });

  test('a revisit after deletion resolves to the add-your-face gate', () async {
    final auth = _FakeAuth(hasFaces: true);
    sl.registerSingleton<AuthService>(auth);

    expect(await resolveFoundAccess(), FoundAccess.ready);

    // Deleted somewhere this app never saw — only the revisit catches it.
    auth.hasFaces = false;

    expect(await resolveFoundAccess(), FoundAccess.noFaceAdded);
  });
}
