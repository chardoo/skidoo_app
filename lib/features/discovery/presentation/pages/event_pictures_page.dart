import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/pictures_fullscreen_viewer.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

class EventPicturesPage extends StatelessWidget {
  const EventPicturesPage({super.key, required this.event});

  final EventDiscovery event;

  // Repeating height pattern for the masonry columns (aspect ratios).
  static const _ratios = [0.75, 1.1, 0.85, 1.3, 0.7, 1.0];

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final pics = event.pictures;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
          color: Colors.white,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.eventName,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15.sp,
              ),
            ),
            Text(
              'by ${event.photographerName}',
              style: TextStyle(color: ext.searchHintColor, fontSize: 11.sp),
            ),
          ],
        ),
      ),
      body: pics.isEmpty
          ? Center(
              child: Text(
                'No photos available',
                style: TextStyle(color: ext.searchHintColor, fontSize: 15.sp),
              ),
            )
          : MasonryGridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8.h,
              crossAxisSpacing: 8.w,
              padding: EdgeInsets.all(12.w),
              itemCount: pics.length,
              itemBuilder: (context, i) {
                final ratio = _ratios[i % _ratios.length];
                return GestureDetector(
                  onTap: () => _openFullscreen(context, pics, i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: AspectRatio(
                      aspectRatio: ratio,
                      child: CachedNetworkImage(
                        imageUrl: pics[i].url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: const Color(0xFF1E2230),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white38,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFF1E2230),
                          child: const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white38,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _openFullscreen(
      BuildContext context, List<EventPicture> pics, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => PicturesFullscreenViewer(
          pictures: pics,
          initialIndex: initialIndex,
        ),
      ),
    );
  }
}
