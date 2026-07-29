import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Full-card tap CTA shown over the media for unauthenticated viewers.
class UnauthCta extends StatelessWidget {
  const UnauthCta({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Semantics(
          button: true,
          label: 'Tap to explore',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
              alignment: Alignment.center,
              child: Text(
                'Tap to explore',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )),
    );
  }
}
