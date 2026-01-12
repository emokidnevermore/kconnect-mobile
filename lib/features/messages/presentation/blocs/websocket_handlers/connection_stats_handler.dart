import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

/// Обработчик ответа на запрос статистики соединения
///
/// Обрабатывает ответ `connection_stats` с информацией о WebSocket соединении
class ConnectionStatsHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    try {
      debugPrint('ConnectionStatsHandler: Processing connection_stats response');
      
      final stats = data['stats'] as Map<String, dynamic>?;
      if (stats != null) {
        debugPrint('ConnectionStatsHandler: Connection stats received:');
        debugPrint('  - Connected: ${stats['connected']}');
        debugPrint('  - Messages sent: ${stats['messages_sent']}');
        debugPrint('  - Messages received: ${stats['messages_received']}');
        debugPrint('  - Connection time: ${stats['connection_time']}');
        // Log other stats if available
      } else {
        debugPrint('ConnectionStatsHandler: No stats data in response');
      }
      
      // Stats are for debugging only, don't update state
      return state;
    } catch (e, stackTrace) {
      debugPrint('ConnectionStatsHandler: Error processing connection_stats: $e');
      debugPrint('ConnectionStatsHandler: Stack trace: $stackTrace');
      return state;
    }
  }
}
