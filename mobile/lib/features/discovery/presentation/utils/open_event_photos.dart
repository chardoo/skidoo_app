import 'package:flutter/material.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/navigation/app_page_routes.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_pictures_page.dart'
    show photosOfEvent;
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Opens an event's photos in the shared full-screen viewer, at [initialIndex].
///
/// The feed used to send people to the event's grid, and the grid then opened
/// this same viewer — a page in between whose only question was "which one?",
/// asked about photos the reader was already looking at. So the feed skips it:
/// "Explore event photos" lands on the photo that was on screen, and swiping
/// there covers the whole album.
///
/// [EventPicturesPage] is still the right screen for the places that arrive
/// without a photo in mind — saved items, the liked and bookmarked grids, a
/// profile — and it still opens this viewer from a tile.
void openEventPhotos(
  BuildContext context,
  EventDiscovery event, {
  int initialIndex = 0,
}) {
  final photos = photosOfEvent(event);
  if (photos.isEmpty) return;

  // The view signal the grid page sent on open. This is that moment now.
  // Fire-and-forget: a recommendation is not worth failing a tap over.
  sl<Api>()
      .dio
      .post('/recommend/${event.id}/view')
      .then((_) {})
      .catchError((Object e) {
    debugPrint('[EventView] view tracking failed: $e');
  });

  Navigator.of(context).push(NoSwipeBackPageRoute<void>(
    builder: (_) => FoundPhotoViewerPage(
      photos: photos,
      initialIndex: initialIndex.clamp(0, photos.length - 1),
      // Named, because there is no album page underneath this one any more:
      // the bar says which event these belong to, and the counter moves onto
      // the photo as a pill.
      title: event.eventName,
    ),
  ));
}
