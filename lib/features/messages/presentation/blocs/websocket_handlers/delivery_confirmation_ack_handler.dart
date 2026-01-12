/// Обработчик события delivery_confirmation_ack
///
/// Обрабатывает подтверждение доставки сообщения.
/// Обновляет статус сообщения на "delivered" (если еще не "read").
library;

import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import '../../../domain/models/message.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

class DeliveryConfirmationAckHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    final deliveryId = data['delivery_id'] as String?;
    final messageId = data['messageId'] as int? ?? data['message_id'] as int?;
    final chatId = data['chatId'] as int? ?? data['chat_id'] as int?;

    if (deliveryId == null || messageId == null || chatId == null) {
      return state;
    }

    debugPrint('DeliveryConfirmationAckHandler: Delivery confirmation ACK for message $messageId in chat $chatId');

    // Get the message to check current status
    final message = state.getMessage(chatId, messageId);
    if (message == null) {
      debugPrint('DeliveryConfirmationAckHandler: Message $messageId not found');
      return state;
    }

    // Only update to delivered if not already read
    if (message.deliveryStatus != MessageDeliveryStatus.read) {
      debugPrint('DeliveryConfirmationAckHandler: Updating message $messageId status to delivered');
      return state.withMessageStatus(chatId, messageId, MessageDeliveryStatus.delivered);
    } else {
      debugPrint('DeliveryConfirmationAckHandler: Message $messageId already read, keeping read status');
      return state;
    }
  }
}
