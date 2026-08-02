import 'package:flutter/material.dart';
import 'package:skidoo_app/core/widgets/media_grid.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/event_card_widget.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// Events as a uniform card grid.
///
/// The heights used to cycle through a six-value pattern to fake a masonry
/// wall. Every card is the same size now — see [MediaGrid].
class EventGridWidget extends StatelessWidget {
  const EventGridWidget({
    super.key,
    required this.photos,
    required this.onCardTap,
  });

  final List<Photo> photos;
  final ValueChanged<Photo> onCardTap;

  @override
  Widget build(BuildContext context) {
    return MediaGrid(
      density: MediaGridDensity.cards,
      padding: MediaGrid.pagePadding,
      itemCount: photos.length,
      itemBuilder: (context, index) => EventCardWidget(
        photo: photos[index],
        onTap: () => onCardTap(photos[index]),
      ),
    );
  }
}
