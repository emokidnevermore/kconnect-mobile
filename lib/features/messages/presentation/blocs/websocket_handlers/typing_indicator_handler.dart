/// Обработчик событий typing_indicator и typing_indicator_end
///
/// Обрабатывает индикаторы набора текста пользователями.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../../auth/presentation/blocs/auth_state.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class TypingIndicatorHandler extends WebSocketEventHandler {
  final bool isStart;

  TypingIndicatorHandler({required this.isStart});

  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    final chatId = data['chatId'] as int? ?? data['chat_id'] as int?;
    final userId = data['userId'] as int? ?? data['user_id'] as int?;

    if (chatId == null || userId == null) {
      return state;
    }

    // Get current user ID to exclude self from typing indicators
    final authState = authBloc.state;
    final currentUserId = authState is AuthAuthenticated ? int.tryParse(authState.user.id) : null;

    // Don't show typing indicator for current user
    if (currentUserId != null && userId == currentUserId) {
      return state;
    }

    if (isStart) {
      debugPrint('TypingIndicatorHandler: User $userId is typing in chat $chatId');
      return state.withTypingUserAdded(chatId, userId);
    } else {
      debugPrint('TypingIndicatorHandler: User $userId stopped typing in chat $chatId');
      return state.withTypingUserRemoved(chatId, userId);
    }
  }
}
