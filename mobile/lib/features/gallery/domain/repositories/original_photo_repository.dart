import 'package:jperg_app/features/gallery/data/datasources/original_photo_remote_data_source.dart';

abstract class OriginalPhotoRepository {
  /// The unbadged file behind [imageId], for writing to the device.
  Future<OriginalPhotoFile> getOriginalPhoto(String imageId);
}
