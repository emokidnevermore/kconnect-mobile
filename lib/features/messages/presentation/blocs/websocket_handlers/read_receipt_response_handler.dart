/// Обработчик события read_receipt_response
///
/// Обрабатывает подтверждение отправки read_receipt от сервера.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../../auth/presentation/blocs/auth_state.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class ReadReceiptResponseHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    final messageId = data['messageId'] as int? ?? data['message_id'] as int?;
    final chatId = data['chatId'] as int? ?? data['chat_id'] as int?;
    final success = data['success'] as bool? ?? false;

    if (messageId == null || chatId == null) {
      debugPrint('ReadReceiptResponseHandler: read_receipt_response received without messageId or chatId');
      return state;
    }

    if (success) {
      debugPrint('ReadReceiptResponseHandler: Read receipt sent successfully for message $messageId in chat $chatId');
      
      // Update state: mark message as read and update unread counts
      var newState = state.withMessageRead(chatId, messageId);
      
      // Get the message to check if it's from another user
      final message = newState.getMessage(chatId, messageId);
      if (message != null) {
        // Get current user ID
        final authState = authBloc.state;
        final currentUserId = authState is AuthAuthenticated ? int.tryParse(authState.user.id) : null;
        // Compare senderId as strings to handle type mismatches
        final messageSenderIdStr = message.senderId?.toString();
        final currentUserIdStr = currentUserId?.toString();
        final isFromCurrentUser = messageSenderIdStr == currentUserIdStr;
        
        // Only update unread count if message is from another user
        if (!isFromCurrentUser) {
          final currentChat = newState.getChat(chatId);
          if (currentChat != null) {
            // If optimistic update already set unreadCount to 0, confirm it
            // Otherwise, decrease unread count for this chat
            // This handles batching of read receipts correctly
            final currentUnreadCount = currentChat.unreadCount;
            
            if (currentUnreadCount == 0) {
              // Optimistic update already applied, just confirm
              // Recalculate to ensure consistency
              newState = newState.withRecalculatedUnreadCounts();
              debugPrint('ReadReceiptResponseHandler: Confirming optimistic update for chat $chatId (unreadCount already 0)');
            } else {
              // Decrease unread count for this chat (normal flow)
              newState = newState.withUpdatedChat(
                chatId,
                (chat) => chat.copyWith(
                  unreadCount: (chat.unreadCount > 0) ? chat.unreadCount - 1 : 0,
                ),
              ).withRecalculatedUnreadCounts();
              debugPrint('ReadReceiptResponseHandler: Decreased unread count for chat $chatId to ${newState.getChat(chatId)?.unreadCount ?? 0}');
            }
          }
        }
      }
      
      return newState;
    } else {
      debugPrint('ReadReceiptResponseHandler: Failed to send read receipt for message $messageId in chat $chatId');
      // If failed, don't mark as read locally - will retry later
      return state;
    }
  }
}
