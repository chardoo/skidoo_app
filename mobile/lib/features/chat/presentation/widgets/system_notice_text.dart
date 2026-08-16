/// Wording for the system notices in a group conversation.
///
/// The server stores only a `system_type` and who did it — never the sentence —
/// so the phrasing lives here and can change without a migration over rows
/// already written. It is also why an old app meeting a newer server's notice
/// shows nothing rather than a blank line: an unrecognised type returns null,
/// and every caller treats null as "draw nothing".
String? systemNoticeText({
  required String systemType,
  required String actorName,
  required bool isMe,
}) {
  final who = isMe ? 'You' : _display(actorName);
  if (who.isEmpty) return null;

  switch (systemType) {
    case 'group_created':
      return isMe ? 'You created this group' : '$who created this group';
    case 'invite_accepted':
      return '$who accepted group invite';
    case 'invite_declined':
      return '$who declined group invite';
    default:
      return null;
  }
}

/// Falls back to "Someone" rather than an empty sentence: a participant row
/// whose name never resolved would otherwise produce " accepted group invite".
String _display(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'Someone' : trimmed;
}
