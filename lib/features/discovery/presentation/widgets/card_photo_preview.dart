import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

class CardPhotoPreviewGrid extends StatelessWidget {
  const CardPhotoPreviewGrid({
    super.key,
    required this.pics,
    required this.ext,
    required this.showBlur,
  });

  final List<EventPicture> pics;
  final AppThemeExtension ext;
  final bool showBlur;

  @override
  Widget build(BuildContext context) {
    final totalExtra = pics.length > 3 ? pics.length - 3 : 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: CardPhotoTile(url: pics[0].url),
        ),
        SizedBox(width: 2.w),
        Expanded(
          flex: 4,
          child: Column(
            children: [
              Expanded(
                child: pics.length > 1
                    ? CardPhotoTile(url: pics[1].url)
                    : CardEmptyTile(ext: ext),
              ),
              SizedBox(height: 2.h),
              Expanded(
                child: pics.length > 2
                    ? CardPhotoTile(
                        url: pics[2].url,
                        blurOverlay: (showBlur && totalExtra > 0)
                            ? '+$totalExtra'
                            : null,
                      )
                    : CardEmptyTile(ext: ext),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CardPhotoTile extends StatelessWidget {
  const CardPhotoTile({super.key, required this.url, this.blurOverlay});
  final String url;
  final String? blurOverlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFF1E2230)),
            errorWidget: (_, __, ___) =>
                Container(color: const Color(0xFF1E2230)),
          ),
          if (blurOverlay != null) ...[
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      color: Colors.white, size: 18.sp),
                  SizedBox(height: 4.h),
                  Text(
                    blurOverlay!,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold),
                  ),
                  Text('more',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 11.sp)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CardGradientPlaceholder extends StatelessWidget {
  const CardGradientPlaceholder({super.key, required this.name});
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
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 64.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class CardEmptyTile extends StatelessWidget {
  const CardEmptyTile({super.key, required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) =>
      Container(color: ext.searchFieldFill);
}
