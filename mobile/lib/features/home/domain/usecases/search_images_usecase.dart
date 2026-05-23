import 'package:equatable/equatable.dart';
import 'package:skidoo_app/features/home/domain/repositories/home_repository.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

class SearchImagesUseCase {
  final HomeRepository _repository;
  SearchImagesUseCase(this._repository);

  Stream<Photo> call(SearchImagesParams params) =>
      _repository.streamEventImages(
        params.eventId,
        params.email,
        params.alwaysPublicImages,
      );
}

class SearchImagesParams extends Equatable {
  final String eventId;
  final String email;
  final bool alwaysPublicImages;
  const SearchImagesParams({
    required this.eventId,
    required this.email,
    this.alwaysPublicImages = false,
  });
  @override
  List<Object?> get props => [eventId, email, alwaysPublicImages];
}
