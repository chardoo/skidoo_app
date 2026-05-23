import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase implements UseCase<void, RegisterParams> {
  final AuthRepository _repository;
  RegisterUseCase(this._repository);

  @override
  Future<void> call(RegisterParams params) async {
    await _repository.register(params.fields, params.image);
  }
}

class RegisterParams extends Equatable {
  final Map<String, String> fields;
  final File image;
  const RegisterParams({required this.fields, required this.image});

  @override
  List<Object?> get props => [fields, image];
}
