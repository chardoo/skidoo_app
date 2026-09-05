import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/core/navigation/external_link.dart';
import 'package:jperg_app/features/chat/presentation/mentions.dart';

/// Every URL a message body can contain, as the app is willing to recognise
/// one.
///
/// Deliberately narrow. It matches an explicit `http(s)://`, and a bare host
/// only when it carries a dot and a plausible top-level domain — so "3.5" and
/// "e.g." in ordinary prose are left as prose. Over-matching here is not a
/// cosmetic problem: every false positive is a word turned into a tap target
/// that opens a "you're leaving the app" sheet for something that was never a
/// link.
final _urlPattern = RegExp(
  r'((?:https?:\/\/)[^\s<>"]+|(?:www\.)[^\s<>"]+|'
  r'[a-zA-Z0-9][a-zA-Z0-9-]*(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}(?:\/[^\s<>"]*)?)',
);

/// Trailing punctuation belongs to the sentence, not the address.
///
/// "have a look at jperg.com." ends in a full stop that is not part of the
/// host, and a closing bracket after a link in parentheses is the same story.
String _trimTrailing(String url) {
  var end = url.length;
  while (end > 0 && '.,;:!?)]}\'"'.contains(url[end - 1])) {
    end--;
  }
  return url.substring(0, end);
}

/// Message body text with `@mentions` picked out and links made tappable.
///
/// Falls back to a plain [Text] the moment there is nothing to highlight, so a
/// conversation with neither costs no more to draw than it did before this
/// existed.
///
/// Links go through [ExternalLink.open], which is the whole point of routing
/// them here rather than handing them to `launchUrl`: one of ours opens the
/// screen it names, and anything else asks before leaving. A link pasted into a
/// chat is written by another person, and that is exactly where both halves of
/// that matter.
class MentionText extends StatefulWidget {
  const MentionText({
    super.key,
    required this.text,
    required this.style,
    required this.mentionStyle,
    this.handles = const {},
    this.displayNames = const {},
    this.myUserId = '',
    this.linkStyle,
  });

  final String text;
  final TextStyle style;

  /// How a mention is drawn. Applied on top of [style], so callers only have to
  /// state what differs — colour and weight.
  final TextStyle mentionStyle;

  /// How a link is drawn. Underlined in the text's own colour when a caller
  /// says nothing, which reads as a link on every bubble colour without the
  /// caller having to know which one it is on.
  final TextStyle? linkStyle;

  /// {userId: handle} for the room's participants.
  final Map<String, String> handles;

  /// {userId: display name}, used to render `@devon_a` as "@Devon".
  final Map<String, String> displayNames;

  /// Whose mentions read as "@You".
  final String myUserId;

  @override
  State<MentionText> createState() => _MentionTextState();
}

class _MentionTextState extends State<MentionText> {
  /// One per link span, and disposed with the widget — a recognizer that
  /// outlives its span leaks, and Flutter says so in debug.
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  /// Splits [text] into plain and link runs, styling the links and wiring each
  /// one to open.
  List<InlineSpan> _linkify(String text, TextStyle? base) {
    final spans = <InlineSpan>[];
    var index = 0;

    for (final match in _urlPattern.allMatches(text)) {
      final raw = _trimTrailing(match.group(0)!);
      if (raw.isEmpty) continue;

      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }

      final recognizer = TapGestureRecognizer()
        ..onTap = () => ExternalLink.open(context, raw);
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: raw,
        style: widget.linkStyle ??
            const TextStyle(decoration: TextDecoration.underline),
        recognizer: recognizer,
      ));

      // Whatever was trimmed off the end is prose and goes back as prose.
      index = match.start + raw.length;
    }

    if (index < text.length) {
      spans.add(TextSpan(text: text.substring(index)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();

    final hasMentions =
        widget.handles.isNotEmpty && widget.text.contains('@');
    final hasLinks = _urlPattern.hasMatch(widget.text);

    // The overwhelmingly common message: neither, and it costs what it always
    // did.
    if (!hasMentions && !hasLinks) {
      return Text(widget.text, style: widget.style);
    }

    // Links only — no mention parsing to do.
    if (!hasMentions) {
      return Text.rich(
        TextSpan(style: widget.style, children: _linkify(widget.text, null)),
      );
    }

    final parsed = Mentions.parse(
      widget.text,
      handles: widget.handles,
      myUserId: widget.myUserId,
      displayNames: widget.displayNames,
    );

    // A mention run is never a link, so only the plain runs between them are
    // scanned. That is also what stops a handle containing a dot from being
    // read as a hostname.
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final span in parsed)
            if (span.isMention)
              TextSpan(
                text: span.text,
                style: widget.style.merge(widget.mentionStyle),
              )
            else
              ..._linkify(span.text, null),
        ],
      ),
    );
  }
}
