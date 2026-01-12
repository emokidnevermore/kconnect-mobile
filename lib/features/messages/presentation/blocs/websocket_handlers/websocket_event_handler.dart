/// Базовый класс для обработчиков WebSocket событий
///
/// Каждый обработчик реализует метод handle, который принимает текущее состояние,
/// данные события, AuthBloc и WebSocket сервис, и возвращает новое состояние.
library;

import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../messages_state.dart';

/// Абстрактный класс для обработчиков WebSocket событий
abstract class WebSocketEventHandler {
  /// Обработать WebSocket событие и вернуть новое состояние
  ///
  /// [state] - текущее состояние
  /// [data] - данные события от WebSocket
  /// [authBloc] - BLoC для получения информации о текущем пользователе
  /// [wsService] - сервис WebSocket для отправки ответов
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  );
}
