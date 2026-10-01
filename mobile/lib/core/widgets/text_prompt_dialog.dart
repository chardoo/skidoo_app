import 'package:flutter/material.dart';

/// A dialog whose text field outlives nothing it depends on.
///
/// The bug this exists to remove, written five times across the app:
///
/// ```dart
/// final controller = TextEditingController(text: initial);
/// final answer = await showDialog<String>(...);   // uses `controller`
/// controller.dispose();                           // ← too early
/// ```
///
/// `showDialog`'s future completes the moment the route is *popped*, but the
/// dialog's widgets stay mounted for the whole exit transition — roughly 150ms
/// of frames in which the field is still painting. Disposing on the line after
/// the `await` kills the controller underneath a live `TextField`, and the
/// damage arrives as three unrelated-looking exceptions:
///
///   A TextEditingController was used after being disposed.
///   A RenderFlex overflowed by 99746 pixels on the bottom.
///   'framework.dart': Failed assertion: '_dependents.isEmpty': is not true.
///
/// The second is the one that sends people looking in the wrong place. It is
/// not a layout mistake: a disposed controller leaves the editable with no
/// usable text metrics, the intrinsic height comes back as garbage, and the
/// number is whatever fell out of the arithmetic. Fixing the lifetime fixes
/// all three, because there is only one fault.
///
/// So the controller is owned by a [StatefulWidget] *inside* the dialog's own
/// subtree. Flutter disposes it when the route is actually gone, which is the
/// only moment that is correct, and no call site has to remember anything.
///
/// Usage mirrors [showDialog] with the controller handed to the builder:
///
/// ```dart
/// final name = await showTextPromptDialog<String>(
///   context: context,
///   initialText: room.name ?? '',
///   builder: (dialogContext, controller) => AlertDialog(
///     content: TextField(controller: controller, autofocus: true),
///     actions: [
///       TextButton(
///         onPressed: () => Navigator.of(dialogContext).pop(controller.text),
///         child: const Text('Save'),
///       ),
///     ],
///   ),
/// );
/// ```
Future<T?> showTextPromptDialog<T>({
  required BuildContext context,
  required Widget Function(
    BuildContext dialogContext,
    TextEditingController controller,
  ) builder,
  String initialText = '',
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (dialogContext) => _TextPromptHost(
      initialText: initialText,
      builder: builder,
    ),
  );
}

class _TextPromptHost extends StatefulWidget {
  const _TextPromptHost({required this.initialText, required this.builder});

  final String initialText;
  final Widget Function(BuildContext, TextEditingController) builder;

  @override
  State<_TextPromptHost> createState() => _TextPromptHostState();
}

class _TextPromptHostState extends State<_TextPromptHost> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    // The whole point of the file. Runs when the route has finished leaving,
    // not when its future completed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}
