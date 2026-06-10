import 'package:flutter/widgets.dart';

/// Whether the user is currently focused inside an editable text field
/// (TextField / TextFormField / any [EditableText]).
///
/// Used by feed keyboard-shortcut handlers (j/k/space/enter) so they don't
/// hijack keystrokes while the user is typing a comment or search query.
///
/// NOTE: a naive `primaryFocus?.context?.widget is EditableText` check does
/// NOT work: for a focused TextField the primary-focus node is owned by the
/// `Focus` widget that `EditableText` builds internally, so its
/// `context.widget` is a `Focus`, not the `EditableText`. We therefore also
/// walk the ancestor chain to find the enclosing [EditableText].
bool isTextInputFocused() {
  final ctx = FocusManager.instance.primaryFocus?.context;
  if (ctx == null) return false;
  if (ctx.widget is EditableText) return true;
  var editing = false;
  ctx.visitAncestorElements((element) {
    if (element.widget is EditableText) {
      editing = true;
      return false; // stop walking
    }
    return true;
  });
  return editing;
}
