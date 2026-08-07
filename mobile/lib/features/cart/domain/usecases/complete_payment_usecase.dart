import 'package:equatable/equatable.dart';
import 'package:jperg_app/core/usecases/usecase.dart';
import 'package:jperg_app/features/cart/domain/repositories/cart_repository.dart';

class CompletePaymentUseCase
    implements UseCase<Map<String, dynamic>, CompletePaymentParams> {
  final CartRepository _repository;
  CompletePaymentUseCase(this._repository);

  @override
  Future<Map<String, dynamic>> call(CompletePaymentParams params) =>
      _repository.completePayment(params.payload);
}

class CompletePaymentParams extends Equatable {
  final Map<String, dynamic> payload;
  const CompletePaymentParams(this.payload);
  @override
  List<Object?> get props => [payload];
}
