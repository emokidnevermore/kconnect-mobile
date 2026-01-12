/// Обработчик события message_deleted
///
/// Обрабатывает удаление сообщения из чата.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class MessageDeletedHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    final chatId = data['chatId'] as int? ?? data['chat_id'] as int?;
    final messageId = data['messageId'] as int? ?? data['message_id'] as int?;

    if (chatId == null || messageId == null) {
      return state;
    }

    debugPrint('MessageDeletedHandler: Message $messageId deleted in chat $chatId');

    // Get current messages
    final currentMessages = state.getChatMessages(chatId);
    final updatedMessages = currentMessages.where((m) => m.id != messageId).toList();

    // Update chat's lastMessage if deleted message was the last one
    if (updatedMessages.isNotEmpty) {
      final newLastMessage = updatedMessages.first; // Messages are sorted newest first
      return state
          .withDeletedMessage(chatId, messageId)
          .withUpdatedChat(
            chatId,
            (chat) => chat.copyWith(lastMessage: newLastMessage),
          );
    }

    return state.withDeletedMessage(chatId, messageId);
  }
}
