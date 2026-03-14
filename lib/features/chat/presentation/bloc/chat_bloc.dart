import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/usecases/usecase.dart';
import 'package:skidoo_app/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:skidoo_app/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:skidoo_app/models/message_model.dart';

part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final GetMessagesUseCase _getMessagesUseCase;
  final GetMoreMessagesUseCase _getMoreMessagesUseCase;
  final SendMessageUseCase _sendMessageUseCase;
  final UpdateMessageUseCase _updateMessageUseCase;

  ChatBloc({
    required GetMessagesUseCase getMessagesUseCase,
    required GetMoreMessagesUseCase getMoreMessagesUseCase,
    required SendMessageUseCase sendMessageUseCase,
    required UpdateMessageUseCase updateMessageUseCase,
  })  : _getMessagesUseCase = getMessagesUseCase,
        _getMoreMessagesUseCase = getMoreMessagesUseCase,
        _sendMessageUseCase = sendMessageUseCase,
        _updateMessageUseCase = updateMessageUseCase,
        super(const ChatState()) {
    on<ChatInitialized>(_onInitialized);
    on<ChatMessageSent>(_onMessageSent);
    on<ChatMessageUpdated>(_onMessageUpdated);
    on<ChatMoreMessagesRequested>(_onMoreMessagesRequested);
  }

  Future<void> _onInitialized(
      ChatInitialized event, Emitter<ChatState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final stream = await _getMessagesUseCase(const NoParams());
      await emit.forEach<List<MessageResponse>>(
        stream,
        onData: (messages) =>
            state.copyWith(isLoading: false, messages: messages),
        onError: (_, __) => state.copyWith(
          isLoading: false,
          errorMessage: 'Failed to load messages.',
        ),
      );
    } on ServerException catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          isLoading: false, errorMessage: 'Failed to connect to chat.'));
    }
  }

  Future<void> _onMessageSent(
      ChatMessageSent event, Emitter<ChatState> emit) async {
    try {
      await _sendMessageUseCase(SendMessageParams(event.message));
    } on ServerException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(
          errorMessage: 'Failed to send message. Please try again.'));
    }
  }

  Future<void> _onMessageUpdated(
      ChatMessageUpdated event, Emitter<ChatState> emit) async {
    try {
      await _updateMessageUseCase(
          UpdateMessageParams(uid: event.uid, message: event.message));
    } on ServerException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to update message.'));
    }
  }

  Future<void> _onMoreMessagesRequested(
      ChatMoreMessagesRequested event, Emitter<ChatState> emit) async {
    try {
      final stream = await _getMoreMessagesUseCase(
          GetMoreMessagesParams(event.lastMessage));
      await emit.forEach<List<MessageResponse>>(
        stream,
        onData: (messages) => state.copyWith(messages: messages),
        onError: (_, __) =>
            state.copyWith(errorMessage: 'Failed to load more messages.'),
      );
    } on ServerException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to load more messages.'));
    }
  }
}
