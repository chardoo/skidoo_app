import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/common/widgets/app_drag_handle.dart';
import 'package:jperg_app/core/common/widgets/jperg_logo.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/settings/data/payments_api.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// The receipt for one payment, and the way to send it somewhere.
///
/// A list of payments answers "did it go through". A receipt answers the other
/// question people have about their own money — *can I show somebody this* —
/// and the answer has to be a file, because the places a receipt gets sent are
/// an email to an employer, a chat with the person who owes you half, a
/// folder kept for tax. Text pasted into a message is not a receipt.
///
/// So it renders itself to a PNG. A widget is already the right description of
/// what a receipt looks like, and [RepaintBoundary] will hand back exactly
/// what is on screen — there is no second layout here to drift from the first.
class PaymentReceiptSheet extends StatefulWidget {
  const PaymentReceiptSheet({super.key, required this.record});

  final PaymentRecord record;

  static Future<void> show(BuildContext context, PaymentRecord record) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PaymentReceiptSheet(record: record),
      );

  @override
  State<PaymentReceiptSheet> createState() => _PaymentReceiptSheetState();
}

class _PaymentReceiptSheetState extends State<PaymentReceiptSheet> {
  /// Wraps the part of the sheet that *is* the receipt — not the drag handle
  /// or the share button, which belong to the app rather than to the record.
  final _receiptKey = GlobalKey();

  bool _sharing = false;

  /// Renders the receipt and hands it to the OS share sheet.
  ///
  /// At 3× regardless of the device's own ratio: a receipt is read at whatever
  /// size the person receiving it chooses, often zoomed, and a 1× capture of a
  /// phone screen is unreadable the moment it leaves the phone.
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('nothing to capture');

      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('nothing encoded');

      final file = await _write(data.buffer.asUint8List());
      if (!mounted) return;

      // Anchored to the button on iPad, where a popover has to come from
      // something.
      final box =
          _shareKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = (box != null && box.hasSize)
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'Receipt · ${widget.record.title}',
        sharePositionOrigin: origin,
      );
      // Only once the sheet has closed — deleting it while the OS still holds
      // it is how a share arrives as a broken attachment.
      try {
        await file.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(context, 'Could not prepare the receipt.');
      }
      debugPrint('[Receipt] share failed: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  final _shareKey = GlobalKey();

  Future<File> _write(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    // The reference rather than a timestamp: a receipt shared twice should be
    // the same file, and the name is what somebody sees in their downloads.
    final id = (widget.record.reference ?? widget.record.id)
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    final file = File('${dir.path}/jperg-receipt-$id.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final r = widget.record;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppDragHandle(),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, 0,
                    AppSpacing.lg.w, AppSpacing.lg.h),
                child: RepaintBoundary(
                  key: _receiptKey,
                  child: _Receipt(record: r, ext: ext),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg.w, 0, AppSpacing.lg.w,
                  AppSpacing.lg.h),
              child: AppButton(
                key: _shareKey,
                fullWidth: true,
                isLoading: _sharing,
                icon: Icons.ios_share_rounded,
                label: 'Share receipt',
                onPressed: _share,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The receipt itself — everything inside this is what gets captured.
///
/// On its own opaque card rather than the sheet's background: the capture
/// takes whatever is painted, and a receipt shared from dark mode with a
/// transparent background arrives as white text on nothing.
class _Receipt extends StatelessWidget {
  const _Receipt({required this.record, required this.ext});

  final PaymentRecord record;
  final AppThemeExtension ext;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _when {
    final date = record.date?.toLocal();
    if (date == null) return '—';
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '${date.day} ${_months[date.month - 1]} ${date.year}, $hh:$mm';
  }

  (Color, String) get _state => switch (record.status) {
        'success' => (ext.accentGold, 'Paid'),
        'failed' => (ext.errorRed, 'Failed'),
        _ => (ext.publicAmber, 'Pending'),
      };

  @override
  Widget build(BuildContext context) {
    final (stateColor, stateLabel) = _state;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Who issued it. A receipt with no issuer on it is a screenshot.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const JpergLogo(height: 22),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    color: stateColor,
                    fontSize: AppTypography.xs,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xl.h),

          // The amount, which is the one thing read at a glance.
          Text(
            '${record.currency} ${record.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: ext.greetingColor,
              fontFamily: AppTypography.displayFontFamily,
              fontSize: AppTypography.xxl,
              fontWeight: AppTypography.bold,
            ),
          ),
          SizedBox(height: AppSpacing.xs.h),
          Text(
            record.title,
            style: TextStyle(
              color: ext.searchHintColor,
              fontSize: AppTypography.sm,
            ),
          ),

          SizedBox(height: AppSpacing.lg.h),
          Divider(color: ext.searchHintColor.withValues(alpha: 0.2), height: 1),
          SizedBox(height: AppSpacing.lg.h),

          if (record.subtitle != null && record.subtitle!.isNotEmpty)
            _Line(label: 'Details', value: record.subtitle!, ext: ext),
          _Line(label: 'Date', value: _when, ext: ext),
          // The number somebody quotes when they write in about it. Last,
          // because it is the line they will be asked for rather than the one
          // they came to read.
          _Line(
            label: 'Reference',
            value: record.reference ?? record.id,
            ext: ext,
            monospace: true,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    required this.ext,
    this.monospace = false,
  });

  final String label;
  final String value;
  final AppThemeExtension ext;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92.w,
            child: Text(
              label,
              style: TextStyle(
                color: ext.searchHintColor,
                fontSize: AppTypography.xs,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: ext.greetingColor,
                fontSize: AppTypography.xs,
                fontWeight: AppTypography.medium,
                // A reference is copied by eye, character by character, and
                // the proportional face makes 1/l and 0/O the same shape.
                fontFeatures:
                    monospace ? const [FontFeature.tabularFigures()] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
