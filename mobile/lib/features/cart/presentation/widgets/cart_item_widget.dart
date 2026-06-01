import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

class CartItemWidget extends StatelessWidget {
  final Photo photo;
  const CartItemWidget({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: Stack(
        children: [
          // ── Image ─────────────────────────────────────────────────────
          Semantics(image: true, label: 'Photo', child: CachedNetworkImage(
            imageUrl: photo.url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: 220.h,
            placeholder: (_, __) => Container(
              height: 220.h,
              color: const Color(0xFF1A1A1A),
              child: const Center(
                child: CircularProgressIndicator(
                    color: Colors.white30, strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: 220.h,
              color: const Color(0xFF1A1A1A),
              child: const Icon(Icons.broken_image_outlined,
                  color: Colors.white38, size: 48),
            ),
          )),

          // ── Remove button ──────────────────────────────────────────────
          Positioned(
            top: 8.h,
            right: 8.w,
            child: Semantics(button: true, label: 'Photo', child: GestureDetector(
              onTap: () =>
                  context.read<CartBloc>().add(CartItemRemoved(photo)),
              child: Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Icon(Icons.close_rounded,
                    color: Colors.white, size: 18.sp),
              ),
            )),
          ),
        ],
      ),
    );
  }
}
