import 'package:skidoo_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

class SaveImagesForFreeUseCase {
  final CartRepository _repository;
  SaveImagesForFreeUseCase(this._repository);

  Future<void> call(List<Photo> photos, {required String clientId}) {
    final items = photos
        .map((p) => {
              'pictureId': p.id,
              'clientId': clientId,
              'userId': p.userId,
            })
        .toList();
    return _repository.saveImagesFree(items);
  }
}
