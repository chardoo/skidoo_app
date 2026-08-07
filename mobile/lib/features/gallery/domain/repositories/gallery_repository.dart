import 'package:jperg_app/models/photos/Photo.dart';

abstract class GalleryRepository {
  Future<List<Photo>> getUserGallery(String clientId);
}
