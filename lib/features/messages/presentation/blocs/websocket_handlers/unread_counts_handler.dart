/// Обработчик события unread_counts
///
/// Обрабатывает обновление счетчиков непрочитанных сообщений для чатов.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../../auth/presentation/blocs/auth_state.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class UnreadCountsHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    final counts = data['counts'] as Map<String, dynamic>?;
    if (counts == null) {
      return state;
    }

    debugPrint('UnreadCountsHandler: Received unread counts update for ${counts.length} chats');

    // Update unread counts for chats
    var updatedState = state;
    counts.forEach((chatIdStr, count) {
      final chatId = int.tryParse(chatIdStr);
      if (chatId != null) {
        final newUnreadCount = count as int? ?? 0;
        final oldUnreadCount = state.getChat(chatId)?.unreadCount ?? 0;
        
        debugPrint('UnreadCountsHandler: Chat $chatId unread count: $oldUnreadCount -> $newUnreadCount');
        
        updatedState = updatedState.withUpdatedChat(
          chatId,
          (chat) => chat.copyWith(unreadCount: newUnreadCount),
        );
        
        // If unread count decreased, mark messages as read locally
        // This helps sync local state with server
        if (newUnreadCount < oldUnreadCount) {
          final authState = authBloc.state;
          final currentUserId = authState is AuthAuthenticated ? int.tryParse(authState.user.id) : null;
          
          // Mark unread messages as read (up to the difference)
          final unreadMessages = updatedState.getUnreadMessages(chatId, currentUserId: currentUserId);
          final messagesToMark = unreadMessages.take(oldUnreadCount - newUnreadCount).toList();
          
          if (messagesToMark.isNotEmpty) {
            final messageIds = messagesToMark.where((m) => m.id != null).map((m) => m.id!).toList();
            if (messageIds.isNotEmpty) {
              updatedState = updatedState.withMessagesRead(chatId, messageIds);
              debugPrint('UnreadCountsHandler: Marked ${messageIds.length} messages as read in chat $chatId');
            }
          }
        }
      }
    });

    // Recalculate total unread count
    return updatedState.withRecalculatedUnreadCounts();
  }
}
