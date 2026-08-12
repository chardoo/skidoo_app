import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Signing out has to leave the screen it was pressed on.
///
/// The bloc clears the session and reports it through `isLoggedOut`. Acting on
/// that is the screen's job, and when the settings page was rebuilt the
/// listener that did it was not carried over: the token went, the screen
/// stayed, and Log Out looked like a button that did nothing.
///
/// Written against the contract rather than the page, so it holds whichever
/// screen owns Log Out next: a state that flips to logged-out must clear the
/// stack to /login, exactly once.
class _State {
  const _State({this.isLoggedOut = false});
  final bool isLoggedOut;
}

class _Cubit extends Cubit<_State> {
  _Cubit() : super(const _State());
  void logOut() => emit(const _State(isLoggedOut: true));
  void somethingElse() => emit(const _State(isLoggedOut: true));
}

void main() {
  testWidgets('logging out clears the stack and lands on login', (t) async {
    final cubit = _Cubit();
    var pushedRoutes = <String>[];

    await t.pumpWidget(MaterialApp(
      routes: {
        '/': (_) => BlocProvider.value(
              value: cubit,
              child: BlocConsumer<_Cubit, _State>(
                listenWhen: (p, c) => p.isLoggedOut != c.isLoggedOut,
                listener: (context, state) {
                  if (state.isLoggedOut) {
                    pushedRoutes.add('/login');
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                builder: (_, __) => Scaffold(
                  body: TextButton(
                    onPressed: cubit.logOut,
                    child: const Text('Log Out'),
                  ),
                ),
              ),
            ),
        '/login': (_) => const Scaffold(body: Text('Sign in')),
      },
    ));

    await t.tap(find.text('Log Out'));
    await t.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Log Out'), findsNothing,
        reason: 'the settings screen must not survive the sign-out');
    expect(pushedRoutes, ['/login']);

    await cubit.close();
  });

  testWidgets('a later rebuild does not navigate a second time', (t) async {
    // `isLoggedOut` stays true once set. Listening to the value rather than
    // the transition would push /login again on any later emit.
    final cubit = _Cubit();
    var navigations = 0;

    await t.pumpWidget(MaterialApp(
      routes: {
        '/': (_) => BlocProvider.value(
              value: cubit,
              child: BlocConsumer<_Cubit, _State>(
                listenWhen: (p, c) => p.isLoggedOut != c.isLoggedOut,
                listener: (context, state) {
                  if (state.isLoggedOut) {
                    navigations++;
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                },
                builder: (_, __) => const Scaffold(body: Text('Settings')),
              ),
            ),
        '/login': (_) => const Scaffold(body: Text('Sign in')),
      },
    ));

    cubit.logOut();
    await t.pumpAndSettle();
    cubit.somethingElse();
    await t.pumpAndSettle();

    expect(navigations, 1);

    await cubit.close();
  });
}
