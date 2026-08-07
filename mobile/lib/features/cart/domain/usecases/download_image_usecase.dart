import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/cart/domain/repositories/cart_repository.dart';

class DownloadImageUseCase implements UseCase<void, DownloadImageParams> {
  final CartRepository _repository;
  DownloadImageUseCase(this._repository);

  @override
  Future<void> call(DownloadImageParams params) =>
      _repository.downloadImage(params.url);
}

class DownloadImageParams extends Equatable {
  final String url;
  const DownloadImageParams(this.url);
  @override
  List<Object?> get props => [url];
}
