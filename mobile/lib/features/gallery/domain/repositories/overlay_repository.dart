import 'package:jperg_app/features/gallery/data/datasources/overlay_remote_data_source.dart';

abstract class OverlayRepository {
  /// Fetches the branded overlay for [imageId].
  /// [photographerName] is sent in the request body alongside `enabled:true`.
  Future<OverlayResult> getOverlayImage(
      String imageId, String photographerName);
}
