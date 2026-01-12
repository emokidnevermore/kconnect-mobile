/// Обработчик события message_edited
///
/// Обрабатывает редактирование сообщения через WebSocket.
/// Обновляет содержимое сообщения и edited_at метку времени.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class MessageEditedHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    // Handle both camelCase and snake_case formats
    final chatId = data['chatId'] as int? ?? data['chat_id'] as int?;
    final messageId = data['messageId'] as int? ?? data['message_id'] as int?;
    
    if (chatId == null || messageId == null) {
      debugPrint('MessageEditedHandler: message_edited received without chatId or messageId');
      return state;
    }

    debugPrint('MessageEditedHandler: Message $messageId edited in chat $chatId');

    // Get the current message
    final currentMessage = state.getMessage(chatId, messageId);
    if (currentMessage == null) {
      debugPrint('MessageEditedHandler: Message $messageId not found in chat $chatId');
      return state;
    }

    // Extract edited message data
    // The edited message data can be in 'message' field or at root level
    final messageData = data['message'] as Map<String, dynamic>? ?? data;
    final editedContent = messageData['content'] as String? ?? messageData['text'] as String?;
    final editedAtStr = messageData['edited_at'] as String? ?? messageData['editedAt'] as String?;

    if (editedContent == null) {
      debugPrint('MessageEditedHandler: No content in edited message data');
      return state;
    }

    // Parse edited_at timestamp
    DateTime? editedAt;
    if (editedAtStr != null) {
      try {
        editedAt = DateTime.parse(editedAtStr).toLocal();
      } catch (e) {
        debugPrint('MessageEditedHandler: Failed to parse edited_at: $e');
        editedAt = DateTime.now();
      }
    } else {
      editedAt = DateTime.now();
    }

    // Update the message with new content and edited_at
    final updatedMessage = currentMessage.copyWith(
      content: editedContent,
      editedAt: editedAt,
    );

    // Update message in state
    var newState = state.withUpdatedMessage(
      chatId,
      messageId,
      (message) => updatedMessage,
    );

    // Update lastMessage in chat if this was the last message
    final currentMessages = state.getChatMessages(chatId);
    if (currentMessages.isNotEmpty && currentMessages.first.id == messageId) {
      newState = newState.withUpdatedChat(
        chatId,
        (chat) => chat.copyWith(
          lastMessage: updatedMessage,
        ),
      );
    }

    debugPrint('MessageEditedHandler: Message $messageId updated with new content: ${editedContent.substring(0, editedContent.length > 50 ? 50 : editedContent.length)}...');
    
    return newState;
  }
}
