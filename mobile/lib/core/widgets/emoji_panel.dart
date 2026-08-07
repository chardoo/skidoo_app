import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

// ── Emoji data ────────────────────────────────────────────────────────────────

const _kEmojiCategories = <String, List<String>>{
  '😀': [
    '😀','😁','😂','🤣','😃','😄','😅','😆','😉','😊',
    '😋','😎','😍','🥰','😘','😗','😙','🥲','😚','🙂',
    '🤗','🤩','🤔','🫡','🤭','🤫','🤐','😐','😑','😶',
    '😏','😒','🙄','😬','🤥','😔','😪','🤤','😴','😷',
    '🤒','🤕','🤢','🤧','🥵','🥶','🥴','😵','🤯','🤠',
    '🥸','🤡','😈','👿','😭','😢','😦','😧','😮','😲',
    '😳','🥺','😱','😨','😰','😥','😓','🤗','🫠','😶',
  ],
  '❤️': [
    '❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔',
    '❤️‍🔥','❤️‍🩹','💕','💞','💓','💗','💖','💘','💝','💟',
    '♥️','🫀','💋','💌','🥰','😍','😘','🫶','🤝','🙌',
  ],
  '👍': [
    '👍','👎','👌','🤌','🤏','✌️','🤞','🫰','🤟','🤘',
    '🤙','👈','👉','👆','🖕','👇','☝️','🫵','👋','🤚',
    '🖐️','✋','🖖','🫱','🫲','💪','🦾','🙏','👏','🫶',
    '🤲','🤝','🤜','🤛','✊','👊','🤚','🖐️','✋','👐',
  ],
  '🎉': [
    '🎉','🎊','🎈','🎀','🎁','🏆','🥇','🥈','🥉','🏅',
    '🎯','🎮','🎲','🎭','🎪','🎨','🎬','🎤','🎧','🎼',
    '🔥','✨','💫','⭐','🌟','💥','🎆','🎇','🌈','☀️',
    '🌊','🌸','🌹','🌺','🍀','🦋','🌙','⚡','🌍','💯',
  ],
  '😂': [
    '😂','🤣','💀','☠️','😹','🐱','🐶','🐭','🐹','🐰',
    '🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷','🐸','🐵',
    '🙈','🙉','🙊','🦄','🐔','🐧','🐦','🦆','🦅','🦉',
    '🦋','🐛','🐝','🐞','🦎','🐍','🦖','🦕','🐠','🐟',
  ],
};

// ── Public widget: emoji toggle button ───────────────────────────────────────

/// Stateless emoji toggle button.
///
/// The panel itself is NOT rendered here — the parent widget renders
/// [EmojiPickerPanel] as a sibling above its input row so it is never
/// clipped or obscured by the keyboard or message list.
class EmojiButton extends StatelessWidget {
  const EmojiButton({
    super.key,
    required this.isOpen,
    required this.onToggle,
    required this.ext,
    this.iconSize,
  });

  final bool isOpen;
  final VoidCallback onToggle;
  final AppThemeExtension ext;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Semantics(button: true, label: 'Toggle', child: GestureDetector(
        onTap: onToggle,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: AppSpacing.xs.h),
          child: Text(
            isOpen ? '⌨️' : '😊',
            style: TextStyle(fontSize: iconSize ?? 20.sp),
          ),
        ),
      )),
    );
  }
}

// ── Helper: insert emoji into a TextEditingController ────────────────────────

void insertEmoji(TextEditingController ctrl, String emoji) {
  final sel = ctrl.selection;
  final text = ctrl.text;
  final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
  final end = sel.isValid ? sel.end.clamp(0, text.length) : text.length;
  final newText = text.replaceRange(start, end, emoji);
  ctrl.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: start + emoji.length),
  );
}

// ── Emoji picker panel ────────────────────────────────────────────────────────

class EmojiPickerPanel extends StatefulWidget {
  const EmojiPickerPanel({
    super.key,
    required this.ext,
    required this.onEmojiSelected,
  });

  final AppThemeExtension ext;
  final ValueChanged<String> onEmojiSelected;

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  String _activeCategory = _kEmojiCategories.keys.first;

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final emojis = _kEmojiCategories[_activeCategory]!;

    return Container(
      height: 220.h,
      decoration: BoxDecoration(
        color: ext.cardSurface,
        border: Border(
          top: BorderSide(
            color: ext.searchHintColor.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // ── Category tabs ───────────────────────────────────────────────────
          SizedBox(
            height: 40.h,
            child: Row(
              children: _kEmojiCategories.keys.map((cat) {
                final active = cat == _activeCategory;
                return Expanded(
                  child: Semantics(button: true, label: 'Cat', child: GestureDetector(
                    onTap: () => setState(() => _activeCategory = cat),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: active
                                ? ext.accentGold
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: active
                              ? null
                              : ext.searchHintColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  )),
                );
              }).toList(),
            ),
          ),

          // ── Emoji grid ──────────────────────────────────────────────────────
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w, vertical: AppSpacing.xs.h),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                mainAxisSpacing: 2.h,
                crossAxisSpacing: 2.w,
                childAspectRatio: 1,
              ),
              itemCount: emojis.length,
              itemBuilder: (_, i) => _EmojiCell(
                emoji: emojis[i],
                ext: ext,
                onTap: () => widget.onEmojiSelected(emojis[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmojiCell extends StatefulWidget {
  const _EmojiCell({
    required this.emoji,
    required this.ext,
    required this.onTap,
  });
  final String emoji;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  State<_EmojiCell> createState() => _EmojiCellState();
}

class _EmojiCellState extends State<_EmojiCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, label: 'Emoji', child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered
                ? widget.ext.accentGold.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(widget.emoji, style: TextStyle(fontSize: 20.sp)),
        ),
      )),
    );
  }
}
