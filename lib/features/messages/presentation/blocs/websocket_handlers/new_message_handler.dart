/// Обработчик события new_message
///
/// Обрабатывает новое сообщение, полученное через WebSocket.
/// Добавляет сообщение в чат и обновляет счетчики непрочитанных.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../../auth/presentation/blocs/auth_state.dart';
import '../../../domain/models/message.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class NewMessageHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    // Handle both chatId (camelCase) and chat_id (snake_case)
    final chatId = data['chatId'] as int? ?? data['chat_id'] as int?;
    if (chatId == null) {
      debugPrint('NewMessageHandler: New message received without chatId');
      return state;
    }

    // Extract message data from the WebSocket payload
    // The message can be nested in 'message' field or be at root level
    final messageData = data['message'] as Map<String, dynamic>? ?? data;

    // Create message from WebSocket message data
    final newMessage = Message.fromWebSocketMessage(messageData);

    // Check if delivery confirmation is required
    final requiresDeliveryConfirmation = data['requires_delivery_confirmation'] as bool? ?? false;

    if (requiresDeliveryConfirmation && newMessage.id != null) {
      // Send delivery confirmation
      final deliveryId = 'delivery_${DateTime.now().millisecondsSinceEpoch}';
      wsService.sendDeliveryConfirmation(
        deliveryId: deliveryId,
        messageId: newMessage.id!,
        chatId: chatId,
      );
      debugPrint('NewMessageHandler: Sent delivery confirmation for message ${newMessage.id}');
    }

    debugPrint('NewMessageHandler: New message in chat $chatId: ${newMessage.content}');

    // Check origin_device_id to prevent processing messages from the same device
    final originDeviceId = data['origin_device_id'] as String?;
    final currentDeviceId = wsService.currentDeviceId;
    
    if (originDeviceId != null && currentDeviceId != null && originDeviceId == currentDeviceId) {
      debugPrint('NewMessageHandler: Message from same device ($originDeviceId), skipping to prevent duplication');
      return state;
    }

    // Check for duplicates before adding
    final currentMessages = state.getChatMessages(chatId);
    final isDuplicate = currentMessages.any((existingMessage) {
      // Check by id
      if (newMessage.id != null && existingMessage.id == newMessage.id) {
        return true;
      }
      // Check by clientMessageId
      if (newMessage.clientMessageId != null && 
          existingMessage.clientMessageId == newMessage.clientMessageId) {
        return true;
      }
      // Check by tempId
      if (newMessage.tempId != null && 
          existingMessage.tempId == newMessage.tempId) {
        return true;
      }
      return false;
    });

    if (isDuplicate) {
      debugPrint('NewMessageHandler: Duplicate message detected, skipping. id: ${newMessage.id}, clientMessageId: ${newMessage.clientMessageId}, tempId: ${newMessage.tempId}');
      return state;
    }

    // Check if message is from current user (from another device)
    final authState = authBloc.state;
    final currentUserId = authState is AuthAuthenticated ? authState.user.id : null;
    final isFromCurrentUser = newMessage.senderId?.toString() == currentUserId?.toString();

    // Don't increment unread count if message is from current user (from another device)
    // Note: We don't check if chat is "open" here because we can't reliably track
    // if the chat screen is currently displayed. Read receipts should only be sent
    // from ChatScreen when the user is actually viewing the chat.
    final shouldIncrementUnread = !isFromCurrentUser;

    // Add message using helper method (which also checks for duplicates)
    final newState = state.withNewMessage(
      chatId,
      newMessage,
      incrementUnread: shouldIncrementUnread,
    );

    // Do NOT send read_receipt automatically here.
    // Read receipts should only be sent from ChatScreen when the chat is actually open.
    // The ChatScreen will handle marking messages as read when the user views them.

    return newState;
  }
}
