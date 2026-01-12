import '../../domain/models/chat.dart';
import '../../domain/models/message.dart';
import '../../domain/repositories/messages_repository.dart';
import '../services/messages_service.dart';

/// Реализация репозитория сообщений
///
/// Предоставляет унифицированный интерфейс для работы с данными сообщений.
/// Делегирует выполнение операций сервису MessagesService.
/// Реализует паттерн Repository для абстракции работы с данными.
class MessagesRepositoryImpl implements MessagesRepository {
  final MessagesService _messagesService;

  /// Конструктор репозитория сообщений
  ///
  /// [messagesService] - сервис для работы с API сообщений
  MessagesRepositoryImpl(this._messagesService);

  /// Получает список чатов пользователя
  ///
  /// Делегирует вызов сервису MessagesService для получения чатов
  @override
  Future<List<Chat>> fetchChats() async {
    return await _messagesService.fetchChats();
  }

  /// Создает новый персональный чат
  ///
  /// Делегирует вызов сервису для создания чата с указанным пользователем
  @override
  Future<int> createChat(int userId, {bool encrypted = false}) async {
    return await _messagesService.createChat(userId, encrypted: encrypted);
  }

  /// Создает новый групповой чат
  ///
  /// Делегирует вызов сервису для создания группового чата
  @override
  Future<int> createGroupChat(String title, List<int> userIds) async {
    return await _messagesService.createGroupChat(title, userIds);
  }

  /// Получает сообщения чата
  ///
  /// Делегирует вызов сервису для получения сообщений указанного чата
  @override
  Future<List<Message>> fetchMessages(int chatId, {int? beforeId}) async {
    return await _messagesService.fetchMessages(chatId, beforeId: beforeId);
  }

  /// Отправляет сообщение в чат
  ///
  /// Делегирует вызов сервису для отправки сообщения в указанный чат
  @override
  Future<void> sendMessage(int chatId, String content, {String messageType = 'text'}) async {
    return await _messagesService.sendMessage(chatId, content, messageType: messageType);
  }

  /// Отмечает чат как прочитанный
  ///
  /// Делегирует вызов сервису для отметки всех сообщений чата как прочитанные
  @override
  Future<int> markChatAsRead(int chatId) async {
    return await _messagesService.markChatAsRead(chatId);
  }

  /// Загружает медиа-файл в чат
  ///
  /// Делегирует вызов сервису для загрузки медиа-файла
  @override
  Future<Message> uploadMedia({
    required int chatId,
    required String filePath,
    required String messageType,
    int? replyToId,
  }) async {
    return await _messagesService.uploadMedia(
      chatId: chatId,
      filePath: filePath,
      messageType: messageType,
      replyToId: replyToId,
    );
  }

  /// Загружает медиа-файл через Base64
  ///
  /// Делегирует вызов сервису для загрузки медиа-файла через Base64
  @override
  Future<Message> uploadMediaBase64({
    required int chatId,
    required String type,
    required String filename,
    required String base64Data,
    int? replyToId,
  }) async {
    return await _messagesService.uploadMediaBase64(
      chatId: chatId,
      type: type,
      filename: filename,
      base64Data: base64Data,
      replyToId: replyToId,
    );
  }

  /// Редактирует сообщение
  ///
  /// Делегирует вызов сервису для редактирования сообщения
  @override
  Future<Message> editMessage(int chatId, int messageId, String content) async {
    return await _messagesService.editMessage(chatId, messageId, content);
  }

  /// Удаляет сообщение
  ///
  /// Делегирует вызов сервису для удаления сообщения
  @override
  Future<void> deleteMessage(int chatId, int messageId) async {
    return await _messagesService.deleteMessage(chatId, messageId);
  }
}
