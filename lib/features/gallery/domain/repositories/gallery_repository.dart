import 'package:skidoo_app/models/photos/Photo.dart';

abstract class GalleryRepository {
  Future<List<Photo>> getUserGallery(String clientId);
}
