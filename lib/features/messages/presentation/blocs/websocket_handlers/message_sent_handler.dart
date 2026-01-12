/// Обработчик события message_sent
///
/// Обрабатывает подтверждение отправки сообщения от сервера.
/// Заменяет временное сообщение на серверное с реальным ID.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../../auth/presentation/blocs/auth_state.dart';
import '../../../domain/models/message.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class MessageSentHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    final clientMessageId = data['clientMessageId'] as String?;
    final chatId = data['chatId'] as int? ?? data['chat_id'] as int?;

    if (clientMessageId == null) {
      debugPrint('MessageSentHandler: message_sent received without clientMessageId');
      return state;
    }

    // The response may contain messageId directly or in a nested structure
    final messageId = data['messageId'] as int?;

    // Update message status and add server message
    // The response format may vary, so we use fromWebSocketMessage which handles both formats
    final serverMessage = Message.fromWebSocketMessage(data);

    // Ensure serverMessage has correct senderId from current user
    final authState = authBloc.state;
    final currentUserId = authState is AuthAuthenticated ? int.tryParse(authState.user.id) : null;
    final currentUserName = authState is AuthAuthenticated ? authState.user.username : null;
    final currentUserUsername = authState is AuthAuthenticated ? authState.user.username : null;

    // Create new message with correct sender info
    final finalServerMessage = Message(
      id: serverMessage.id,
      senderId: serverMessage.senderId ?? currentUserId,
      senderName: serverMessage.senderName ?? currentUserName,
      senderUsername: serverMessage.senderUsername ?? currentUserUsername,
      messageType: serverMessage.messageType,
      content: serverMessage.content,
      createdAt: serverMessage.createdAt,
      clientMessageId: serverMessage.clientMessageId,
      tempId: serverMessage.tempId,
      deliveryStatus: MessageDeliveryStatus.sent,
      deviceId: serverMessage.deviceId,
      replyToId: serverMessage.replyToId, // Preserve replyToId from server
      photoUrl: serverMessage.photoUrl,
      videoUrl: serverMessage.videoUrl,
      audioUrl: serverMessage.audioUrl,
      fileSize: serverMessage.fileSize,
      mimeType: serverMessage.mimeType,
      editedAt: serverMessage.editedAt,
      forwardedFromId: serverMessage.forwardedFromId,
    );

    if (chatId == null) {
      debugPrint('MessageSentHandler: No chatId provided');
      return state;
    }

    // Find and replace temporary message with server message
    final currentMessages = state.getChatMessages(chatId);

    // Check if we need to replace a temporary message
    final hasTemporaryMessage = currentMessages.any(
      (m) => m.clientMessageId == clientMessageId && m.deliveryStatus == MessageDeliveryStatus.sending,
    );

    if (hasTemporaryMessage) {
      // Replace temporary message
      return state.withUpdatedMessageByClientId(
        chatId,
        clientMessageId,
        (message) {
          if (message.deliveryStatus == MessageDeliveryStatus.sending) {
            return finalServerMessage.copyWith(deliveryStatus: MessageDeliveryStatus.sent);
          }
          return message;
        },
      ).withUpdatedChat(
        chatId,
        (chat) => chat.copyWith(
          lastMessage: finalServerMessage.copyWith(deliveryStatus: MessageDeliveryStatus.sent),
          updatedAt: finalServerMessage.createdAt,
        ),
      );
    } else {
      // Check for duplicates before adding
      final isDuplicate = currentMessages.any((existingMessage) {
        // Check by id
        if (finalServerMessage.id != null && existingMessage.id == finalServerMessage.id) {
          return true;
        }
        // Check by clientMessageId
        if (finalServerMessage.clientMessageId != null && 
            existingMessage.clientMessageId == finalServerMessage.clientMessageId) {
          return true;
        }
        // Check by tempId
        if (finalServerMessage.tempId != null && 
            existingMessage.tempId == finalServerMessage.tempId) {
          return true;
        }
        return false;
      });

      if (isDuplicate) {
        debugPrint('MessageSentHandler: Duplicate message detected, skipping. id: ${finalServerMessage.id}, clientMessageId: ${finalServerMessage.clientMessageId}, tempId: ${finalServerMessage.tempId}');
        return state;
      }

      // Add new message if it doesn't exist (withNewMessage also checks for duplicates)
      debugPrint('MessageSentHandler: Message sent successfully, messageId: $messageId, chatId: $chatId');
      return state.withNewMessage(
        chatId,
        finalServerMessage.copyWith(deliveryStatus: MessageDeliveryStatus.sent),
        incrementUnread: false,
      );
    }
  }
}
