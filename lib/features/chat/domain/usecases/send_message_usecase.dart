import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:skidoo_app/models/message_model.dart';

class SendMessageUseCase implements UseCase<void, SendMessageParams> {
  final ChatRepository _repository;
  SendMessageUseCase(this._repository);

  @override
  Future<void> call(SendMessageParams params) =>
      _repository.addMessage(params.message);
}

class SendMessageParams extends Equatable {
  final Message message;
  const SendMessageParams(this.message);
  @override
  List<Object?> get props => [];
}

class UpdateMessageUseCase implements UseCase<void, UpdateMessageParams> {
  final ChatRepository _repository;
  UpdateMessageUseCase(this._repository);

  @override
  Future<void> call(UpdateMessageParams params) =>
      _repository.updateMessage(params.uid, params.message);
}

class UpdateMessageParams extends Equatable {
  final String uid;
  final Message message;
  const UpdateMessageParams({required this.uid, required this.message});
  @override
  List<Object?> get props => [uid];
}
