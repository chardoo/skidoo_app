import 'package:flutter/material.dart';
import 'package:jperg_app/features/chat/presentation/mentions.dart';

/// Message body text with `@mentions` picked out.
///
/// Falls back to a plain [Text] the moment there is nothing to highlight, so a
/// conversation with no mentions in it costs no more to draw than it did
/// before this existed.
class MentionText extends StatelessWidget {
  const MentionText({
    super.key,
    required this.text,
    required this.style,
    required this.mentionStyle,
    this.handles = const {},
    this.displayNames = const {},
    this.myUserId = '',
  });

  final String text;
  final TextStyle style;

  /// How a mention is drawn. Applied on top of [style], so callers only have to
  /// state what differs — colour and weight.
  final TextStyle mentionStyle;

  /// {userId: handle} for the room's participants.
  final Map<String, String> handles;

  /// {userId: display name}, used to render `@devon_a` as "@Devon".
  final Map<String, String> displayNames;

  /// Whose mentions read as "@You".
  final String myUserId;

  @override
  Widget build(BuildContext context) {
    if (handles.isEmpty || !text.contains('@')) {
      return Text(text, style: style);
    }

    final spans = Mentions.parse(
      text,
      handles: handles,
      myUserId: myUserId,
      displayNames: displayNames,
    );
    if (spans.length == 1 && !spans.first.isMention) {
      return Text(text, style: style);
    }

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final span in spans)
            TextSpan(
              text: span.text,
              style: span.isMention ? style.merge(mentionStyle) : null,
            ),
        ],
      ),
    );
  }
}
