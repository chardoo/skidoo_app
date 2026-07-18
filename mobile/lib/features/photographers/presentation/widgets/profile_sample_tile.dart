import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/models/photographer/photographer_sample.dart';

class PhotographerSampleTile extends StatelessWidget {
  const PhotographerSampleTile({super.key, required this.sample, required this.onTap});

  final PhotographerSample sample;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(button: true, label: 'Sample photo', child: GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4.r),
        child: CachedNetworkImage(
          imageUrl: sample.url,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            color: const Color(0xFF1B2A22),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 1.5),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFF1B2A22),
            child: const Icon(Icons.broken_image_rounded,
                color: Colors.white24, size: 24),
          ),
        ),
      ),
    ));
  }
}
