import 'package:kconnect_mobile/features/messages/domain/models/chat.dart';
import 'package:kconnect_mobile/features/messages/domain/models/message.dart';

/// Интерфейс репозитория для операций с сообщениями и чатами
///
/// Определяет контракт для работы с чатами, сообщениями и их состоянием.
/// Обеспечивает доступ к данным мессенджера через стандартизированный интерфейс.
abstract class MessagesRepository {
  /// Получает список чатов пользователя
  ///
  /// Returns: список всех чатов пользователя с последними сообщениями
  Future<List<Chat>> fetchChats();

  /// Создает новый чат с пользователем
  ///
  /// [userId] - ID пользователя для создания чата
  /// [encrypted] - включить шифрование для чата
  /// Returns: ID созданного чата
  Future<int> createChat(int userId, {bool encrypted = false});

  /// Создает новый групповой чат
  ///
  /// [title] - название группового чата
  /// [userIds] - список ID пользователей для добавления в группу
  /// Returns: ID созданного чата
  Future<int> createGroupChat(String title, List<int> userIds);

  /// Получает сообщения из чата
  ///
  /// [chatId] - ID чата для получения сообщений
  /// [beforeId] - ID сообщения для пагинации (загрузить сообщения до этого ID)
  /// Returns: список сообщений из указанного чата
  Future<List<Message>> fetchMessages(int chatId, {int? beforeId});

  /// Отправляет сообщение в чат
  ///
  /// [chatId] - ID чата для отправки сообщения
  /// [content] - текст сообщения
  /// [messageType] - тип сообщения ('text', 'image', 'video')
  Future<void> sendMessage(int chatId, String content, {String messageType = 'text'});

  /// Отмечает чат как прочитанный
  ///
  /// [chatId] - ID чата для отметки как прочитанного
  /// Returns: количество отмеченных сообщений
  Future<int> markChatAsRead(int chatId);

  /// Загружает медиа-файл в чат
  ///
  /// [chatId] - ID чата
  /// [filePath] - путь к файлу на устройстве
  /// [messageType] - тип сообщения: 'photo' или 'video'
  /// [replyToId] - ID сообщения, на которое отвечаем (опционально)
  /// Returns: Объект Message с информацией о загруженном файле
  Future<Message> uploadMedia({
    required int chatId,
    required String filePath,
    required String messageType,
    int? replyToId,
  });

  /// Загружает медиа-файл через Base64
  ///
  /// [chatId] - ID чата
  /// [type] - тип файла: 'photo', 'video', или 'audio'
  /// [filename] - имя файла
  /// [base64Data] - Base64-кодированные данные файла
  /// [replyToId] - ID сообщения, на которое отвечаем (опционально)
  /// Returns: Объект Message с информацией о загруженном файле
  Future<Message> uploadMediaBase64({
    required int chatId,
    required String type,
    required String filename,
    required String base64Data,
    int? replyToId,
  });

  /// Редактирует сообщение
  ///
  /// [chatId] - ID чата
  /// [messageId] - ID сообщения для редактирования
  /// [content] - новый текст сообщения
  /// Returns: Обновленное сообщение
  Future<Message> editMessage(int chatId, int messageId, String content);

  /// Удаляет сообщение
  ///
  /// [chatId] - ID чата
  /// [messageId] - ID сообщения для удаления
  Future<void> deleteMessage(int chatId, int messageId);
}
