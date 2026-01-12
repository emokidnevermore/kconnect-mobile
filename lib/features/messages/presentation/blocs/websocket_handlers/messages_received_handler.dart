/// Обработчик события messages
///
/// Обрабатывает получение списка сообщений чата от сервера.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../domain/models/message.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class MessagesReceivedHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    final chatId = data['chat_id'] as int?;
    if (chatId == null) {
      debugPrint('MessagesReceivedHandler: Received messages response without chat_id');
      return state;
    }

    final messagesData = data['messages'] as List<dynamic>? ?? [];
    final messages = messagesData
        .map((messageJson) => Message.fromJson(messageJson as Map<String, dynamic>))
        .toList();

    // Sort messages by creation time (newest first)
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Determine if there are more messages to load
    // If we received the full limit (50), assume there might be more
    final hasMore = messages.length >= 50;

    debugPrint('MessagesReceivedHandler: Received ${messages.length} messages for chat $chatId, hasMore: $hasMore');

    return state
        .withChatMessages(chatId, messages)
        .withChatMessageStatus(chatId, MessagesStatus.success)
        .copyWith(chatHasMoreMessages: {
          ...state.chatHasMoreMessages,
          chatId: hasMore,
        });
  }
}
