import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/cart/domain/repositories/cart_repository.dart';

class PayForImagesUseCase
    implements UseCase<Map<String, dynamic>, PayForImagesParams> {
  final CartRepository _repository;
  PayForImagesUseCase(this._repository);

  @override
  Future<Map<String, dynamic>> call(PayForImagesParams params) =>
      _repository.initiatePayment(params.email, params.amount);
}

class PayForImagesParams extends Equatable {
  final String email;
  final String amount;
  const PayForImagesParams({required this.email, required this.amount});
  @override
  List<Object?> get props => [email, amount];
}
