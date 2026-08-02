import 'package:flutter/material.dart';
import 'package:skidoo_app/core/widgets/media_grid.dart';
import 'package:skidoo_app/features/home/presentation/widgets/photographer_card_widget.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

/// Photographers as a uniform card grid.
///
/// The heights used to cycle through a six-value pattern to fake a masonry
/// wall. Every card is the same size now — see [MediaGrid].
class PhotographerGridWidget extends StatelessWidget {
  const PhotographerGridWidget({super.key, required this.photographers});

  final List<PhotographerModel> photographers;

  @override
  Widget build(BuildContext context) {
    return MediaGrid(
      density: MediaGridDensity.cards,
      padding: MediaGrid.pagePadding,
      itemCount: photographers.length,
      itemBuilder: (context, index) => PhotographerCardWidget(
        photographer: photographers[index],
      ),
    );
  }
}
