import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/gallery/domain/repositories/gallery_repository.dart';
import 'package:jperg_app/models/photos/Photo.dart';

class GetGalleryUseCase implements UseCase<List<Photo>, GetGalleryParams> {
  final GalleryRepository _repository;
  GetGalleryUseCase(this._repository);

  @override
  Future<List<Photo>> call(GetGalleryParams params) =>
      _repository.getUserGallery(params.clientId);
}

class GetGalleryParams extends Equatable {
  final String clientId;
  const GetGalleryParams(this.clientId);
  @override
  List<Object?> get props => [clientId];
}
