/// What the OS has decided about notifications for this app.
///
/// Three states, not two, because "no" and "not yet asked" call for opposite
/// behaviour: one is a dialog worth showing, the other is a decision to leave
/// alone. Collapsing them into a bool is what made the app re-ask on every
/// launch — and `requestPermission(fallbackToSettings: true)` does not quietly
/// return false once the OS is done showing its dialog, it sends the person to
/// the system settings page. Ten seconds after opening the app. Every time.
enum PushPermission {
  /// Never asked. The dialog will actually appear.
  undecided,

  /// Allowed — including iOS's provisional and ephemeral, where notifications
  /// arrive quietly rather than not at all.
  granted,

  /// Refused. Only the system settings app can change this now, so nothing the
  /// app does unprompted is welcome.
  denied;

  bool get isGranted => this == PushPermission.granted;
}
