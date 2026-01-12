/// Обработчик события error
///
/// Обрабатывает ошибки от WebSocket сервера.
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class ErrorHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    final errorMessage = data['message'] as String? ?? 'Unknown error';
    final errorCode = data['code'] as String?;
    final shouldReconnect = data['reconnect'] as bool? ?? false;

    debugPrint('ErrorHandler: WebSocket error: $errorMessage (code: $errorCode, reconnect: $shouldReconnect)');

    // Handle different error codes
    switch (errorCode) {
      case 'AUTH_REQUIRED':
      case 'AUTH_FAILED':
        debugPrint('ErrorHandler: Authentication error, will trigger reconnection with new token');
        // WebSocket service will handle reconnection automatically
        // We just update the state to reflect the error
        return state.copyWith(
          wsConnectionState: WebSocketConnectionState.error,
          error: 'Требуется авторизация. Переподключение...',
        );

      case 'INVALID_FORMAT':
        return state.copyWith(error: 'Неверный формат сообщения');

      case 'MISSING_CHAT_ID':
        return state.copyWith(error: 'Отсутствует ID чата');

      case 'GET_CHATS_FAILED':
        return state.copyWith(
          status: MessagesStatus.failure,
          error: 'Не удалось загрузить чаты',
        );

      case 'GET_MESSAGES_FAILED':
        final chatId = data['chat_id'] as int?;
        if (chatId != null) {
          return state.withChatMessageStatus(chatId, MessagesStatus.failure).copyWith(
                error: 'Не удалось загрузить сообщения',
              );
        }
        return state.copyWith(error: 'Не удалось загрузить сообщения');

      case 'SEND_FAILED':
      case 'message_send_failed':
        return state.copyWith(error: 'Не удалось отправить сообщение');

      case 'DELETE_FAILED':
        return state.copyWith(error: 'Не удалось удалить сообщение');

      case 'MSG_TOO_BIG':
        return state.copyWith(error: 'Сообщение слишком большое (максимум 64 KB)');

      case 'RATE_LIMIT':
        debugPrint('ErrorHandler: Rate limit exceeded, client should delay message sending');
        // Client should implement rate limiting logic in MessagesBloc
        return state.copyWith(error: 'Превышен лимит частоты сообщений (50 сообщений за 10 секунд). Подождите немного.');

      case 'UNKNOWN_MESSAGE_TYPE':
        return state.copyWith(error: 'Неизвестный тип сообщения');

      case 'CHAT_NOT_FOUND':
        return state.copyWith(error: 'Чат не найден');

      case 'MESSAGE_NOT_FOUND':
        return state.copyWith(error: 'Сообщение не найдено');

      case 'PERMISSION_DENIED':
        return state.copyWith(error: 'Недостаточно прав для выполнения действия');

      case 'UPLOAD_FAILED':
        return state.copyWith(error: 'Не удалось загрузить файл. Проверьте размер файла (максимум 50 MB).');

      case 'INVALID_FILE_TYPE':
        return state.copyWith(error: 'Неподдерживаемый тип файла');

      case 'EDIT_NOT_ALLOWED':
        return state.copyWith(error: 'Редактирование этого сообщения запрещено');

      case 'DELETE_NOT_ALLOWED':
        return state.copyWith(error: 'Удаление этого сообщения запрещено');

      case 'SERVER_ERROR':
      case 'INTERNAL_ERROR':
        return state.copyWith(
          error: 'Ошибка сервера. Попробуйте позже.',
          wsConnectionState: shouldReconnect ? WebSocketConnectionState.error : state.wsConnectionState,
        );

      case 'NETWORK_ERROR':
        return state.copyWith(
          error: 'Ошибка сети. Проверьте подключение к интернету.',
          wsConnectionState: WebSocketConnectionState.error,
        );

      case 'TIMEOUT':
        return state.copyWith(
          error: 'Таймаут запроса. Попробуйте еще раз.',
        );

      default:
        // Provide user-friendly error message
        String userMessage;
        if (errorMessage.contains('Network') || errorMessage.contains('network')) {
          userMessage = 'Ошибка сети. Проверьте подключение к интернету.';
        } else if (errorMessage.contains('Timeout') || errorMessage.contains('timeout')) {
          userMessage = 'Таймаут запроса. Попробуйте еще раз.';
        } else if (errorMessage.contains('Failed') || errorMessage.contains('failed')) {
          userMessage = 'Операция не выполнена. Попробуйте еще раз.';
        } else {
          userMessage = errorMessage;
        }

        return state.copyWith(
          error: userMessage,
          wsConnectionState: shouldReconnect ? WebSocketConnectionState.error : state.wsConnectionState,
        );
    }
  }
}
