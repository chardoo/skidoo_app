import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:skidoo_app/models/message_model.dart';

class GetMessagesUseCase
    implements UseCase<Stream<List<MessageResponse>>, NoParams> {
  final ChatRepository _repository;
  GetMessagesUseCase(this._repository);

  @override
  Future<Stream<List<MessageResponse>>> call(NoParams params) =>
      _repository.getInitialMessages();
}

class GetMoreMessagesUseCase
    implements
        UseCase<Stream<List<MessageResponse>>, GetMoreMessagesParams> {
  final ChatRepository _repository;
  GetMoreMessagesUseCase(this._repository);

  @override
  Future<Stream<List<MessageResponse>>> call(GetMoreMessagesParams params) =>
      _repository.getMoreMessages(params.lastMessage);
}

class GetMoreMessagesParams extends Equatable {
  final MessageResponse lastMessage;
  const GetMoreMessagesParams(this.lastMessage);
  @override
  List<Object?> get props => [];
}
