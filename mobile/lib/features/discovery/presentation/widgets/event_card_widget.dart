import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

class EventCardWidget extends StatelessWidget {
  const EventCardWidget({
    super.key,
    required this.photo,
    required this.height,
    this.onTap,
  });

  final Photo photo;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Semantics(button: true, child: GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background image or gradient placeholder ───────────────
              photo.url.isNotEmpty
                  ? SkidooImage(
                      imageUrl: photo.url,
                      fit: BoxFit.cover,
                      semanticLabel: photo.eventName.isNotEmpty
                          ? '${photo.eventName} event cover'
                          : 'Event cover',
                      placeholder: (_, __) =>
                          _GradientPlaceholder(name: photo.eventName),
                      errorWidget: (_, __, ___) =>
                          _GradientPlaceholder(name: photo.eventName),
                    )
                  : _GradientPlaceholder(name: photo.eventName),

              // ── Bottom gradient overlay ───────────────────────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.45, 1.0],
                      colors: [ext.cardOverlayStart, ext.cardOverlayEnd],
                    ),
                  ),
                ),
              ),

              // ── Event name + date ─────────────────────────────────────
              Positioned(
                left: 10.w,
                right: 10.w,
                bottom: 10.h,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      photo.eventName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(blurRadius: 4, color: Colors.black45),
                        ],
                      ),
                    ),
                    if (photo.eventDate.isNotEmpty) ...[
                      SizedBox(height: 3.h),
                      Text(
                        _formatDate(photo.eventDate),
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  String _formatDate(String raw) {
    try {
      return DateFormat.yMMMd().format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }
}

// ── Gradient placeholder ──────────────────────────────────────────────────────

class _GradientPlaceholder extends StatelessWidget {
  const _GradientPlaceholder({required this.name});
  final String name;

  static const _palette = [
    [Color(0xFF3A5BA0), Color(0xFF1E3A6E)],
    [Color(0xFF6B3A8F), Color(0xFF3D1F5A)],
    [Color(0xFF2E7D4F), Color(0xFF1A4D30)],
    [Color(0xFF8F4A3A), Color(0xFF5A2A1E)],
    [Color(0xFF2E6B7D), Color(0xFF1A404D)],
    [Color(0xFF7D3A6B), Color(0xFF4D1F40)],
  ];

  @override
  Widget build(BuildContext context) {
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % _palette.length;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _palette[idx],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 56.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
