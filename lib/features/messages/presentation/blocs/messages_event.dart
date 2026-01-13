/// События для управления сообщениями в BLoC
///
/// Определяет все возможные события, которые могут происходить
/// в системе сообщений: загрузка чатов, отправка сообщений,
/// WebSocket события, управление статусом прочтения.
library;

import '../../../../services/messenger_websocket_service.dart';
import '../../domain/models/message.dart';

/// Базовый класс для всех событий сообщений
abstract class MessagesEvent {}

class LoadChatsEvent extends MessagesEvent {}

class RefreshChatsEvent extends MessagesEvent {}

class SearchChatsEvent extends MessagesEvent {
  final String query;

  SearchChatsEvent(this.query);
}

class InitMessagesEvent extends MessagesEvent {}

class ConnectWebSocketEvent extends MessagesEvent {}

class DisconnectWebSocketEvent extends MessagesEvent {}

class WebSocketMessageReceivedEvent extends MessagesEvent {
  final Map<String, dynamic> message;

  WebSocketMessageReceivedEvent(this.message);
}

class WebSocketConnectionChangedEvent extends MessagesEvent {
  final WebSocketConnectionState state;

  WebSocketConnectionChangedEvent(this.state);
}

class LoadChatMessagesEvent extends MessagesEvent {
  final int chatId;
  final int? beforeId; // ID сообщения для пагинации (загрузить сообщения до этого ID)

  LoadChatMessagesEvent(this.chatId, {this.beforeId});
}

class LoadMoreChatMessagesEvent extends MessagesEvent {
  final int chatId;

  LoadMoreChatMessagesEvent(this.chatId);
}

class SendMessageEvent extends MessagesEvent {
  final int chatId;
  final String content;
  final String messageType;
  final int? replyToId;

  SendMessageEvent({
    required this.chatId,
    required this.content,
    this.messageType = 'text',
    this.replyToId,
  });
}

class CreateChatEvent extends MessagesEvent {
  final int userId;
  final bool encrypted;

  CreateChatEvent({
    required this.userId,
    this.encrypted = false,
  });
}

class CreateGroupChatEvent extends MessagesEvent {
  final String title;
  final List<int> userIds;

  CreateGroupChatEvent({
    required this.title,
    required this.userIds,
  });
}

class UpdateMessageStatusEvent extends MessagesEvent {
  final String clientMessageId;
  final MessageDeliveryStatus status;

  UpdateMessageStatusEvent({
    required this.clientMessageId,
    required this.status,
  });
}

class MarkChatAsReadEvent extends MessagesEvent {
  final int chatId;

  MarkChatAsReadEvent({
    required this.chatId,
  });
}

class MarkChatAsReadOptimisticallyEvent extends MessagesEvent {
  final int chatId;

  MarkChatAsReadOptimisticallyEvent({
    required this.chatId,
  });
}

class SendMediaMessageEvent extends MessagesEvent {
  final int chatId;
  final String filePath;
  final String messageType; // 'photo' or 'video'
  final int? replyToId;

  SendMediaMessageEvent({
    required this.chatId,
    required this.filePath,
    required this.messageType,
    this.replyToId,
  });
}

class SendMediaBase64Event extends MessagesEvent {
  final int chatId;
  final String type; // 'photo', 'video', or 'audio'
  final String filename;
  final String base64Data;
  final int? replyToId;

  SendMediaBase64Event({
    required this.chatId,
    required this.type,
    required this.filename,
    required this.base64Data,
    this.replyToId,
  });
}

class EditMessageEvent extends MessagesEvent {
  final int chatId;
  final int messageId;
  final String content;

  EditMessageEvent({
    required this.chatId,
    required this.messageId,
    required this.content,
  });
}

class DeleteMessageEvent extends MessagesEvent {
  final int chatId;
  final int messageId;

  DeleteMessageEvent({
    required this.chatId,
    required this.messageId,
  });
}

class ForwardMessageEvent extends MessagesEvent {
  final int fromChatId;
  final int messageId;
  final int toChatId;

  ForwardMessageEvent({
    required this.fromChatId,
    required this.messageId,
    required this.toChatId,
  });
}

class LoadPostEvent extends MessagesEvent {
  final int postId;

  LoadPostEvent({
    required this.postId,
  });
}

class ClearPostCacheEvent extends MessagesEvent {}

class ResetMessagesEvent extends MessagesEvent {}
