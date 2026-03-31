import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

/// Full-width swipeable photo carousel — Instagram / TikTok style.
class PostPhotoCarousel extends StatelessWidget {
  const PostPhotoCarousel({
    super.key,
    required this.pics,
    required this.pageController,
    required this.showBlur,
    required this.onDoubleTap,
  });

  final List<EventPicture> pics;
  final PageController pageController;
  final bool showBlur;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: pageController,
      itemCount: pics.length,
      itemBuilder: (context, index) {
        final pic = pics[index];
        final isLastLocked = showBlur && index == 2 && pics.length > 3;

        return GestureDetector(
          onDoubleTap: onDoubleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo
              CachedNetworkImage(
                imageUrl: pic.url,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: const Color(0xFF111111)),
                errorWidget: (_, __, ___) =>
                    Container(color: const Color(0xFF111111)),
              ),

              // Lock overlay on last visible tile (unauthenticated)
              if (isLastLocked) _LockedOverlay(remaining: pics.length - 3),
            ],
          ),
        );
      },
    );
  }
}

// ── Locked overlay ────────────────────────────────────────────────────────────

class _LockedOverlay extends StatelessWidget {
  const _LockedOverlay({required this.remaining});
  final int remaining;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.lock_rounded,
                    color: Colors.white, size: 24.sp),
              ),
              SizedBox(height: 12.h),
              Text(
                '+$remaining more photos',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Sign in to unlock',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Gradient placeholder ──────────────────────────────────────────────────────

class CardGradientPlaceholder extends StatelessWidget {
  const CardGradientPlaceholder({super.key, required this.name});
  final String name;

  static const _palette = [
    [Color(0xFF1a1a2e), Color(0xFF16213e)],
    [Color(0xFF0f3460), Color(0xFF533483)],
    [Color(0xFF1a0533), Color(0xFF3d0066)],
    [Color(0xFF001a2c), Color(0xFF003366)],
    [Color(0xFF1a0000), Color(0xFF4d0000)],
    [Color(0xFF002200), Color(0xFF004d00)],
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
          color: Colors.white.withValues(alpha: 0.08),
          fontSize: 120.sp,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class CardEmptyTile extends StatelessWidget {
  const CardEmptyTile({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(color: const Color(0xFF111111));
}
