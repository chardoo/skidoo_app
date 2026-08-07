/// OneSignal application id.
///
/// Must match `ONESIGNAL_APP_ID` on the backend — it is set on both the
/// `picco-main` service and the `picco-worker-model` worker in render.yaml,
/// the latter being where the push tasks actually run. A mismatch registers
/// this device against a different OneSignal app: the backend's sends still
/// return 200, just with `recipients: 0`, so nothing arrives and nothing
/// errors on either side.
///
/// Not a secret — it identifies the app, it does not authorise sending. Only
/// the REST API key does that, and it lives on the server.
const String kOneSignalAppId = '60167062-760f-472a-9995-f28f62114009';
