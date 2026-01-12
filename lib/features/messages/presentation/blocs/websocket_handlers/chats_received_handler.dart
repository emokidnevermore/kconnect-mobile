/// Обработчик события chats
///
/// Обрабатывает получение списка чатов от сервера.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../domain/models/chat.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class ChatsReceivedHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    final chatsData = data['chats'] as List<dynamic>? ?? [];
    final chats = chatsData
        .map((chatJson) => Chat.fromJson(chatJson as Map<String, dynamic>))
        .toList();

    debugPrint('ChatsReceivedHandler: Received ${chats.length} chats');

    // Use helper method to update chats
    return state.withChats(chats);
  }
}
