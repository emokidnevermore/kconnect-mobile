/// Обработчик события message_read
///
/// Обрабатывает событие, когда сообщение было прочитано другим пользователем.
/// Обновляет статус доставки сообщения на "read" для сообщений текущего пользователя.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../../auth/presentation/blocs/auth_state.dart';
import '../../../domain/models/message.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class MessageReadHandler extends WebSocketEventHandler {
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
    final userId = data['userId'] as int? ?? data['user_id'] as int?;

    if (chatId == null || messageId == null) {
      debugPrint('MessageReadHandler: message_read received without chatId or messageId');
      return state;
    }

    debugPrint('MessageReadHandler: Message $messageId in chat $chatId was read by user $userId');

    // Get current user ID to check if this is our message
    final authState = authBloc.state;
    final currentUserId = authState is AuthAuthenticated ? int.tryParse(authState.user.id) : null;

    if (currentUserId == null) {
      debugPrint('MessageReadHandler: Current user ID is null, skipping');
      return state;
    }

    // Get the message to check if it's from current user
    final message = state.getMessage(chatId, messageId);
    if (message == null) {
      debugPrint('MessageReadHandler: Message $messageId not found in chat $chatId');
      return state;
    }

    // Compare senderId as strings to handle type mismatches
    final messageSenderIdStr = message.senderId?.toString();
    final currentUserIdStr = currentUserId.toString();

    // Update status only for our own messages
    if (messageSenderIdStr == currentUserIdStr) {
      debugPrint('MessageReadHandler: Updating message $messageId status to read');
      return state.withMessageStatus(chatId, messageId, MessageDeliveryStatus.read);
    } else {
      debugPrint('MessageReadHandler: Message $messageId is not from current user, skipping');
      return state;
    }
  }
}
