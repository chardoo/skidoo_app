import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/models/booking_model.dart';

/// "Create Quote" — the photographer pricing a job they were picked for.
///
/// Line items rather than one figure, because that is what the requester is
/// being asked to agree to: "full day coverage" and "drone, two hours" are two
/// decisions, and a single number invites the reply "what does that include?".
///
/// The total is computed here and again on the server, and the server's is the
/// one that binds. What this shows is a preview — including what the
/// photographer actually nets, which is the figure they care about and the one
/// a quote form usually hides until the money arrives short.
class QuoteComposerSheet extends StatefulWidget {
  const QuoteComposerSheet({
    super.key,
    required this.clientName,
    required this.requestTitle,
    required this.terms,
    this.previous,
  });

  final String clientName;
  final String requestTitle;
  final BookingTerms terms;

  /// A quote already sent, when this is a revision. Its lines are pre-filled —
  /// a revised quote is usually the same job at a different price, and retyping
  /// six items to change one is how people give up and send a number in chat.
  final RequestQuote? previous;

  @override
  State<QuoteComposerSheet> createState() => _QuoteComposerSheetState();
}

class _QuoteComposerSheetState extends State<QuoteComposerSheet> {
  final List<_LineControllers> _lines = [];
  final _notes = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final previous = widget.previous;
    if (previous != null && previous.lineItems.isNotEmpty) {
      for (final item in previous.lineItems) {
        _lines.add(_LineControllers(
          label: item.label,
          amount: item.amount == 0 ? '' : _plain(item.amount),
        ));
      }
      _notes.text = previous.notes ?? '';
    } else {
      // Two to start with: the design's "Primary Service" and "Additional
      // Option". One row reads as a single-figure form, which is the thing
      // line items exist to avoid.
      _lines.add(_LineControllers(label: '', amount: ''));
      _lines.add(_LineControllers(label: '', amount: ''));
    }
    for (final line in _lines) {
      line.amountCtrl.addListener(_recompute);
    }
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _notes.dispose();
    super.dispose();
  }

  void _recompute() => setState(() {});

  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  double get _total {
    var sum = 0.0;
    for (final line in _lines) {
      sum += double.tryParse(line.amountCtrl.text.trim()) ?? 0;
    }
    return sum;
  }

  /// Whether there is anything worth sending: at least one line with both a
  /// description and a price, and a total above zero.
  bool get _valid {
    if (_total <= 0) return false;
    return _lines.any((line) =>
        line.labelCtrl.text.trim().isNotEmpty &&
        (double.tryParse(line.amountCtrl.text.trim()) ?? 0) > 0);
  }

  void _addLine() {
    setState(() {
      final line = _LineControllers(label: '', amount: '');
      line.amountCtrl.addListener(_recompute);
      _lines.add(line);
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index).dispose();
    });
  }

  void _submit() {
    if (!_valid || _submitting) return;
    setState(() => _submitting = true);
    // Only the lines somebody actually filled in. An empty row left behind by
    // the two the form starts with is not a free service; it is a blank.
    final items = <QuoteLineItem>[
      for (final line in _lines)
        if (line.labelCtrl.text.trim().isNotEmpty &&
            (double.tryParse(line.amountCtrl.text.trim()) ?? 0) > 0)
          QuoteLineItem(
            label: line.labelCtrl.text.trim(),
            amount: double.parse(line.amountCtrl.text.trim()),
          ),
    ];
    Navigator.of(context).pop((
      items: items,
      notes: _notes.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final total = _total;
    final deposit = total * widget.terms.depositPercent / 100;
    final net = total * (100 - widget.terms.platformFeePercent) / 100;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: ext.homeBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: AppSpacing.md.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999.r),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg.w, AppSpacing.lg.h, AppSpacing.lg.w, 0,
                ),
                children: [
                  Text(
                    widget.previous == null ? 'Create Quote' : 'Revise Quote',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Booking proposal for ${widget.clientName}',
                    style: TextStyle(
                      color: ext.searchHintColor, fontSize: 13.sp,
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg.h),
                  _label('Services included', ext),
                  for (var i = 0; i < _lines.length; i++)
                    _lineRow(i, ext),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addLine,
                      icon: Icon(Icons.add, size: 16.sp, color: ext.accentGold),
                      label: Text(
                        'Add service item',
                        style: TextStyle(
                          color: ext.accentGold,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  _label('Notes / terms (optional)', ext),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    maxLength: 2000,
                    style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
                    decoration: InputDecoration(
                      hintText:
                          'Special instructions, payment terms, deadlines…',
                      hintStyle: TextStyle(
                        color: ext.searchHintColor, fontSize: 13.sp,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md.r),
                      ),
                    ),
                  ),
                  SizedBox(height: AppSpacing.md.h),
                  _summary(total, deposit, net, ext),
                  SizedBox(height: AppSpacing.lg.h),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.w, 0, AppSpacing.lg.w, AppSpacing.lg.h,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: ext.searchHintColor, fontSize: 14.sp,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md.w),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46.h,
                      child: ElevatedButton(
                        onPressed: _valid && !_submitting ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ext.accentGold,
                          disabledBackgroundColor:
                              ext.accentGold.withValues(alpha: 0.35),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                        ),
                        child: Text(
                          'Send Quote',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, AppThemeExtension ext) => Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _lineRow(int index, AppThemeExtension ext) {
    final line = _lines[index];
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: line.labelCtrl,
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
              decoration: InputDecoration(
                isDense: true,
                hintText: index == 0
                    ? 'Full day coverage (10 hours)'
                    : 'Drone coverage (2 hours)',
                hintStyle:
                    TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(width: AppSpacing.sm.w),
          Expanded(
            flex: 2,
            child: TextField(
              controller: line.amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              // Digits and a single decimal point. A comma typed as a thousands
              // separator would otherwise parse as nothing and silently price
              // the line at zero.
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textAlign: TextAlign.right,
              style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
              decoration: InputDecoration(
                isDense: true,
                prefixText: 'GHS ',
                prefixStyle:
                    TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
                hintText: '0',
                hintStyle:
                    TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md.r),
                ),
              ),
            ),
          ),
          // The first two rows are the form's own structure; removing them
          // would leave an empty sheet with nothing to fill in.
          if (_lines.length > 1)
            IconButton(
              icon: Icon(
                Icons.close_rounded, size: 18.sp, color: ext.searchHintColor,
              ),
              onPressed: () => _removeLine(index),
            ),
        ],
      ),
    );
  }

  Widget _summary(
    double total, double deposit, double net, AppThemeExtension ext,
  ) =>
      Container(
        padding: EdgeInsets.all(AppSpacing.md.w),
        decoration: BoxDecoration(
          color: ext.accentGold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.md.r),
        ),
        child: Column(
          children: [
            _row('Total proposed', total, ext, bold: true),
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm.h),
              child: Divider(
                height: 1,
                color: ext.searchHintColor.withValues(alpha: 0.2),
              ),
            ),
            _row(
              'Client pays now (${widget.terms.depositPercent}%)', deposit, ext,
            ),
            _row(
              'You receive (after ${widget.terms.platformFeePercent}% fee)',
              net,
              ext,
              highlight: true,
            ),
          ],
        ),
      );

  Widget _row(
    String label,
    double amount,
    AppThemeExtension ext, {
    bool bold = false,
    bool highlight = false,
  }) =>
      Padding(
        padding: EdgeInsets.symmetric(vertical: 3.h),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: bold ? ext.greetingColor : ext.searchHintColor,
                  fontSize: bold ? 14.sp : 12.sp,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            Text(
              'GHS ${NumberFormat('#,##0.00').format(amount)}',
              style: TextStyle(
                color: highlight
                    ? ext.accentGold
                    : (bold ? ext.greetingColor : ext.searchHintColor),
                fontSize: bold ? 15.sp : 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _LineControllers {
  _LineControllers({required String label, required String amount})
      : labelCtrl = TextEditingController(text: label),
        amountCtrl = TextEditingController(text: amount);

  final TextEditingController labelCtrl;
  final TextEditingController amountCtrl;

  void dispose() {
    labelCtrl.dispose();
    amountCtrl.dispose();
  }
}
