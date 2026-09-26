import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_text_field.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/features/feedback/data/feedback_api.dart';
import 'package:jperg_app/features/feedback/feedback_prompt.dart';

/// Asking somebody what they think, and what they wish the app did.
///
/// Two steps, and the second one is the point. A star alone is a number on a
/// dashboard; the sentence after it is the only part anybody can act on, so
/// the stars are a way *into* the question rather than the question itself.
///
/// What the score changes is what is asked next, because the two situations
/// are not the same conversation: somebody who gave two stars is telling us
/// something is wrong and should be asked what, and somebody who gave five is
/// pleased and can be asked what to build next. Asking a disappointed person
/// for feature ideas reads as not having listened.
///
/// Nothing here can fail in a way the person sees. They have been generous
/// enough to answer a prompt; handing them an error about it afterwards is the
/// worst possible end to that. A failed send is recorded as *not answered*, so
/// the opinion is asked for again rather than lost.
class FeedbackSheet extends StatefulWidget {
  const FeedbackSheet({
    super.key,
    this.api,
    this.startOnFeature = false,
  });

  final FeedbackApi? api;

  /// Opens straight on the feature-request step, skipping the stars.
  ///
  /// For the permanent entry point in Settings: somebody who went looking for
  /// "Suggest a feature" has already decided what they want to say, and making
  /// them rate the app first to say it is a toll.
  final bool startOnFeature;

  /// The prompt, as it appears by itself.
  static Future<void> show(
    BuildContext context, {
    FeedbackApi? api,
    bool startOnFeature = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      // Dismissible on purpose. A prompt somebody cannot close is a prompt
      // they answer dishonestly to get rid of.
      builder: (_) => FeedbackSheet(api: api, startOnFeature: startOnFeature),
    );
  }

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

enum _Step { stars, words, thanks }

class _FeedbackSheetState extends State<FeedbackSheet> {
  late final FeedbackApi _api = widget.api ?? FeedbackApi();
  late final TextEditingController _message = TextEditingController();

  late _Step _step = widget.startOnFeature ? _Step.words : _Step.stars;
  int _rating = 0;
  bool _sending = false;

  /// True when this sheet was opened to collect a feature request rather than
  /// a rating — either from Settings, or from a happy rating.
  bool get _asksForFeature => widget.startOnFeature || _rating >= 4;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickStar(int value) async {
    setState(() {
      _rating = value;
      _step = _Step.words;
    });
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);

    final text = _message.text.trim();
    var ok = true;

    // The rating goes first and goes on its own, so a score is recorded even
    // if the words fail to send — they are two rows on the server and two
    // different things to lose.
    if (!widget.startOnFeature && _rating > 0) {
      ok = await _api.submit(
        kind: FeedbackKind.rating,
        rating: _rating,
        // A low score's explanation belongs *with* the score, not filed as a
        // feature request: "uploads fail" is not a thing to build.
        message: _asksForFeature ? null : (text.isEmpty ? null : text),
      );
    }
    if (_asksForFeature && text.isNotEmpty) {
      final filed = await _api.submit(
        kind: FeedbackKind.featureRequest,
        message: text,
      );
      ok = ok && filed;
    }

    if (ok) {
      await FeedbackPrompt.noteAnswered();
    } else {
      // Not recorded as answered: ask again rather than lose it.
      await FeedbackPrompt.noteDismissed();
    }

    if (!mounted) return;
    setState(() {
      _sending = false;
      _step = _Step.thanks;
    });
  }

  void _close() {
    Navigator.of(context).maybePop();
    if (_step != _Step.thanks) {
      // Closed without answering: the repeat window starts now.
      FeedbackPrompt.noteDismissed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      // The keyboard's room comes out of the sheet, so the field being typed
      // into is never under it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg.w, AppSpacing.md.h, AppSpacing.lg.w, AppSpacing.xl.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            switch (_step) {
              _Step.stars => _stars(ext),
              _Step.words => _words(ext),
              _Step.thanks => _thanks(ext),
            },
          ],
        ),
      ),
    );
  }

  Widget _title(AppThemeExtension ext, String text) => Text(
        text,
        style: TextStyle(
          color: ext.greetingColor,
          fontFamily: AppTypography.displayFontFamily,
          fontSize: 18.sp,
          fontWeight: FontWeight.w700,
        ),
      );

  Widget _body(AppThemeExtension ext, String text) => Padding(
        padding: EdgeInsets.only(top: AppSpacing.xs.h),
        child: Text(
          text,
          style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
        ),
      );

  // ── Step one ────────────────────────────────────────────────────────────

  Widget _stars(AppThemeExtension ext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _title(ext, 'How are you finding Jperg?'),
          _body(ext, 'It takes a second, and it shapes what we build next.'),
          SizedBox(height: AppSpacing.lg.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                Semantics(
                  button: true,
                  label: '$star star${star == 1 ? '' : 's'}',
                  child: IconButton(
                    onPressed: () => _pickStar(star),
                    icon: Icon(
                      star <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 36.sp,
                      color: star <= _rating
                          ? ext.accentGold
                          : ext.searchHintColor,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: AppSpacing.sm.h),
          Center(
            child: TextButton(
              onPressed: _close,
              child: Text(
                'Not now',
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
              ),
            ),
          ),
        ],
      );

  // ── Step two ────────────────────────────────────────────────────────────

  Widget _words(AppThemeExtension ext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _title(
            ext,
            _asksForFeature
                ? 'What should we build next?'
                : 'What went wrong?',
          ),
          _body(
            ext,
            _asksForFeature
                ? 'Tell us what would make Jperg better for you.'
                : 'Tell us what to fix, and we will look at it.',
          ),
          SizedBox(height: AppSpacing.md.h),
          AppTextField(
            controller: _message,
            hint: _asksForFeature
                ? 'I would love it if…'
                : 'What happened?',
            maxLines: 4,
            minLines: 3,
            textCapitalization: TextCapitalization.sentences,
          ),
          SizedBox(height: AppSpacing.md.h),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  // Skipping is a real answer when the stars were the point:
                  // the score is already worth having on its own.
                  onPressed: _sending ? null : _send,
                  child: Text(
                    'Skip',
                    style:
                        TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: ext.accentGold,
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md.r),
                    ),
                  ),
                  child: _sending
                      ? SizedBox(
                          height: 18.h,
                          width: 18.h,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Send',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      );

  // ── Step three ──────────────────────────────────────────────────────────

  Widget _thanks(AppThemeExtension ext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Icon(Icons.favorite_rounded,
                color: ext.accentGold, size: 40.sp),
          ),
          SizedBox(height: AppSpacing.md.h),
          Center(child: _title(ext, 'Thank you')),
          Center(
            child: _body(
              ext,
              _asksForFeature
                  ? 'We read every one of these.'
                  : 'We will look into it.',
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: FilledButton.styleFrom(
              backgroundColor: ext.accentGold,
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md.r),
              ),
            ),
            child: Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
}

/// Opens the sheet from Settings, where it is always available.
///
/// A prompt that appears on its own timetable is not a channel — somebody who
/// wants to say something today should not have to wait for the app to ask.
/// Straight to the feature step, because somebody who went looking for
/// "Suggest a feature" has already decided what they want to say.
Future<void> openFeedbackSheet(BuildContext context,
        {bool startOnFeature = true}) =>
    FeedbackSheet.show(context, startOnFeature: startOnFeature);
