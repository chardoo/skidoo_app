/// Where the app's requests go.
///
/// One constant, because the host was written out three times — the Dio
/// client, the chat REST client and the chat socket — and three copies of a
/// value that must agree is three chances for them not to. They are reached
/// through the same gateway and there is no arrangement in which only one of
/// them should move.
///
/// [host] is the gateway, which fans out to every service behind it: `/api`
/// to main, `/chat` and `/chat/ws` to chat, and so on.
///
/// Which deployment
/// ────────────────
/// There are two, and a build picks one:
///
///     flutter build appbundle --release                             production
///     flutter build appbundle --release --dart-define=USE_TEST_API=true  test
///
/// **Production is the default, deliberately.** A release built with the flag
/// forgotten points at production, which is the harmless mistake; the other way
/// round ships a store build talking to a test backend, and nothing about the
/// running app would say so.
///
/// It is a compile-time constant rather than something read at startup, which
/// is what keeps [host] `const` — [ChatConfig] holds it in a `static const`,
/// and a value resolved at runtime could not be used there. It also means the
/// chosen host is the only one in the binary, so a test build cannot be made to
/// talk to production by anything the app does later.
///
/// Flutter has no `.env` to read at build time. `--dart-define` *is* the
/// mechanism; if a file is easier to rotate than a flag, Flutter reads one
/// natively with `--dart-define-from-file=env/test.json`, where that file is
/// `{"USE_TEST_API": "true"}`. Same constant either way.
///
/// For a host that is neither — a laptop running the gateway, a branch
/// deployment — [apiHostOverride] takes whatever it is given and wins over the
/// switch. That is for development; the switch is for releases.
class ApiConfig {
  ApiConfig._();

  /// The two deployments, both written down here so the choice between them is
  /// visible in one place rather than inferred from a build command.
  ///
  /// Each carries no trailing slash and no path: everything below appends to
  /// it, so a trailing slash makes `//api` and a path makes `/api/api`.
  static const String production = 'https://api.piccotechnologies.com';
  static const String test = 'https://api-test.piccotechnologies.com';

  /// Whether this build points at the test deployment.
  ///
  /// `false` unless `--dart-define=USE_TEST_API=true` was passed. Anything that
  /// is not exactly `true` reads as false, which is the right way round for a
  /// flag whose absence must mean production.
  static const bool useTestApi =
      bool.fromEnvironment('USE_TEST_API', defaultValue: false);

  /// An explicit host, for pointing the app somewhere that is neither of the
  /// two — `--dart-define=API_HOST=http://192.168.1.10:8000`.
  ///
  /// Empty means "not given". Wins over [useTestApi] because it is the more
  /// specific instruction: somebody naming a host has said which one.
  static const String apiHostOverride =
      String.fromEnvironment('API_HOST', defaultValue: '');

  /// The gateway this build talks to.
  static const String host = apiHostOverride.length > 0
      ? apiHostOverride
      : (useTestApi ? test : production);

  /// Main's routes, which all sit under `/api` — see the prefix every router
  /// in that service is registered with.
  static const String apiBaseUrl = '$host/api';

  /// The socket scheme for [host].
  ///
  /// Derived rather than written down a second time: an `https` host whose
  /// socket was left as `ws` fails the upgrade, and the two being separate
  /// strings is exactly how that happens.
  static String get wsHost =>
      host.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://');

  /// What a build is pointing at, for the one place that should say so out
  /// loud. Not shown in release UI — it is for logs and the about screen.
  static String get environmentName {
    if (apiHostOverride.isNotEmpty) return 'custom';
    return useTestApi ? 'test' : 'production';
  }
}
