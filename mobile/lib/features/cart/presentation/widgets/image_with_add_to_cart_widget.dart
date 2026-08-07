import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:jperg_app/models/photos/Photo.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

class ImageWithAddToCartWidget extends StatelessWidget {
  final Photo photo;
  const ImageWithAddToCartWidget({super.key, required this.photo});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10.r),
      child: Stack(
        children: [
          // ── Image ───────────────────────────────────────────────────────
          JpergImage(
            imageUrl: photo.url,
            semanticLabel: 'Photo',
            fit: BoxFit.cover,
            width: double.infinity,
            placeholder: (context, __) => Container(
              height: 150.h,
              color: JpergImagePlaceholder.colorOf(context),
              child: const Center(
                child: CircularProgressIndicator(
                    color: Colors.white30, strokeWidth: 2),
              ),
            ),
            errorWidget: (context, __, ___) => Container(
              height: 150.h,
              color: JpergImagePlaceholder.colorOf(context),
              child: const Icon(Icons.broken_image_outlined,
                  color: Colors.white38, size: 40),
            ),
          ),

          // ── Price badge ─────────────────────────────────────────────────
          Positioned(
            top: 8.h,
            right: 8.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: AppSpacing.xs.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                'GhC ${photo.price}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // ── Cart / download button ──────────────────────────────────────
          Positioned(
            bottom: 8.h,
            right: 8.w,
            child: Semantics(button: true, label: 'Cart', child: GestureDetector(
              onTap: () {
                if (photo.price == 0) {
                  context.read<CartBloc>().add(CartImageDownloaded(photo.url));
                  AppSnackBar.info(context, 'Downloading…');
                } else {
                  context.read<CartBloc>().add(CartItemAdded(photo));
                  AppSnackBar.success(context, 'Added to cart');
                }
              },
              child: Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Icon(
                  photo.price == 0
                      ? Icons.download_rounded
                      : Icons.shopping_cart_rounded,
                  color: Colors.white,
                  size: 18.sp,
                ),
              ),
            )),
          ),
        ],
      ),
    );
  }
}
