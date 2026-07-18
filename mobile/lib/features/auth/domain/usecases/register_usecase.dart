import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/auth/domain/repositories/auth_repository.dart';

class RegisterUseCase implements UseCase<void, RegisterParams> {
  final AuthRepository _repository;
  RegisterUseCase(this._repository);

  @override
  Future<void> call(RegisterParams params) async {
    await _repository.register(params.fields, params.imageBytes, params.imageFilename);
  }
}

class RegisterParams extends Equatable {
  final Map<String, String> fields;
  final Uint8List? imageBytes;
  final String? imageFilename;
  const RegisterParams({required this.fields, this.imageBytes, this.imageFilename});

  @override
  List<Object?> get props => [fields, imageBytes, imageFilename];
}
