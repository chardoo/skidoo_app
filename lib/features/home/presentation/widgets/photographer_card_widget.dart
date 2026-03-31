import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

class PhotographerCardWidget extends StatelessWidget {
  const PhotographerCardWidget({
    super.key,
    required this.photographer,
    required this.height,
    this.onTap,
  });

  final PhotographerModel photographer;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background: real image or gradient placeholder ─────────
              photographer.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: photographer.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          _GradientPlaceholder(name: photographer.name),
                      errorWidget: (_, __, ___) =>
                          _GradientPlaceholder(name: photographer.name),
                    )
                  : _GradientPlaceholder(name: photographer.name),

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

              // ── Name + rating ─────────────────────────────────────────
              Positioned(
                left: 10.w,
                right: 10.w,
                bottom: 10.h,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      photographer.name,
                      maxLines: 1,
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
                    if (photographer.rating != null) ...[
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Icon(Icons.star_rounded,
                              color: ext.accentGold, size: 13.sp),
                          SizedBox(width: 3.w),
                          Text(
                            photographer.rating!.toStringAsFixed(1),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gradient placeholder shown when no imageUrl is available ──────────────────

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
          color: Colors.white.withOpacity(0.35),
          fontSize: 56.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
