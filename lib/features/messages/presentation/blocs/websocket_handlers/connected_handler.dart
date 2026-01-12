/// Обработчик события connected
///
/// Обрабатывает успешное подключение и аутентификацию WebSocket.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class ConnectedHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    // Authentication successful - update connection state to connected
    debugPrint('ConnectedHandler: WebSocket authenticated successfully');

    // Automatically load chats to show unread badge immediately
    debugPrint('ConnectedHandler: Auto-loading chats after WebSocket connection');
    wsService.sendGetChatsMessage();

    return state.copyWith(wsConnectionState: WebSocketConnectionState.connected);
  }
}
