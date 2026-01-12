/// Сервис для работы с API системы сообщений
///
/// Предоставляет методы для взаимодействия с сервером сообщений:
/// получение чатов, сообщений, создание чатов, отправка сообщений.
/// Обрабатывает сетевые запросы и преобразование данных.
library;

import 'package:dio/dio.dart';
import '../../../../services/api_client/dio_client.dart';
import '../../domain/models/chat.dart';
import '../../domain/models/message.dart';

/// Сервис API для системы сообщений
class MessagesService {
  final DioClient _client = DioClient();

  /// Получает список чатов пользователя
  ///
  /// Выполняет GET запрос к API для получения всех чатов текущего пользователя.
  /// Преобразует полученные данные в объекты Chat.
  ///
  /// Returns: Список объектов Chat
  /// Throws: Exception при ошибке сети или сервера
  Future<List<Chat>> fetchChats() async {
    try {
      final res = await _client.get('/apiMes/messenger/chats');

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        final chatsData = List<Map<String, dynamic>>.from(data['chats'] ?? []);
        return chatsData.map((chatJson) => Chat.fromJson(chatJson)).toList();
      } else {
        throw Exception('Не удалось загрузить чаты: ${res.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Не удалось загрузить чаты: ${e.response?.statusCode ?? 'Ошибка сети'}');
    } catch (e) {
      rethrow;
    }
  }

  /// Создает новый персональный чат с пользователем
  ///
  /// Выполняет POST запрос для создания нового чата с указанным пользователем.
  /// Поддерживает опцию шифрования чата.
  ///
  /// [userId] - ID пользователя, с которым нужно создать чат
  /// [encrypted] - флаг шифрования чата (по умолчанию false)
  /// Returns: ID созданного чата
  /// Throws: Exception при ошибке создания чата
  Future<int> createChat(int userId, {bool encrypted = false}) async {
    try {
      final res = await _client.post('/apiMes/messenger/chats/personal', {
        'user_id': userId,
        'encrypted': encrypted,
      });

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['chat_id'] as int;
        } else {
          throw Exception('Не удалось создать чат: ${data['message'] ?? 'Неизвестная ошибка'}');
        }
      } else {
        throw Exception('Не удалось создать чат: ${res.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Не удалось создать чат: ${e.response?.statusCode ?? 'Ошибка сети'}');
    } catch (e) {
      rethrow;
    }
  }

  /// Создает новый групповой чат
  ///
  /// Выполняет POST запрос для создания нового группового чата.
  ///
  /// [title] - название группового чата
  /// [userIds] - список ID пользователей для добавления в группу
  /// Returns: ID созданного чата
  /// Throws: Exception при ошибке создания чата
  Future<int> createGroupChat(String title, List<int> userIds) async {
    try {
      final res = await _client.post('/apiMes/messenger/chats/group', {
        'title': title,
        'user_ids': userIds,
      });

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['chat_id'] as int;
        } else {
          throw Exception('Не удалось создать групповой чат: ${data['message'] ?? 'Неизвестная ошибка'}');
        }
      } else {
        throw Exception('Не удалось создать групповой чат: ${res.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Не удалось создать групповой чат: ${e.response?.statusCode ?? 'Ошибка сети'}');
    } catch (e) {
      rethrow;
    }
  }

  /// Получает список сообщений чата
  ///
  /// Выполняет GET запрос для получения сообщений указанного чата.
  /// Поддерживает пагинацию через параметр before_id.
  /// Сортирует сообщения по времени создания (новые первыми).
  ///
  /// [chatId] - ID чата, сообщения которого нужно получить
  /// [beforeId] - ID сообщения для пагинации (загрузить сообщения до этого ID)
  /// Returns: Список объектов Message, отсортированный по времени (новые первыми)
  /// Throws: Exception при ошибке сети или сервера
  Future<List<Message>> fetchMessages(int chatId, {int? beforeId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (beforeId != null) {
        queryParams['before_id'] = beforeId;
      }

      final res = await _client.get(
        '/apiMes/messenger/chats/$chatId/messages',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        final messagesData = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        final messages = messagesData.map((messageJson) => Message.fromJson(messageJson)).toList();

        // Сортировка сообщений по времени создания (новые первыми)
        messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return messages;
      } else {
        throw Exception('Не удалось загрузить сообщения: ${res.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Не удалось загрузить сообщения: ${e.response?.statusCode ?? 'Ошибка сети'}');
    } catch (e) {
      rethrow;
    }
  }

  /// Отправляет сообщение в чат
  ///
  /// Выполняет POST запрос для отправки нового сообщения в указанный чат.
  /// Поддерживает различные типы сообщений (текст, изображения и т.д.).
  ///
  /// [chatId] - ID чата, в который отправляется сообщение
  /// [content] - содержимое сообщения
  /// [messageType] - тип сообщения ('text', 'image' и т.д.)
  /// Throws: Exception при ошибке отправки сообщения
  Future<void> sendMessage(int chatId, String content, {String messageType = 'text'}) async {
    try {
      final res = await _client.post('/apiMes/messenger/chats/$chatId/messages', {
        'content': content,
        'message_type': messageType,
      });

      if (res.statusCode != 200) {
        throw Exception('Не удалось отправить сообщение: ${res.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Не удалось отправить сообщение: ${e.response?.statusCode ?? 'Ошибка сети'}');
    } catch (e) {
      rethrow;
    }
  }

  /// Отмечает все сообщения чата как прочитанные
  ///
  /// Выполняет POST запрос для отметки всех сообщений в чате как прочитанные.
  /// Возвращает количество отмеченных сообщений.
  ///
  /// [chatId] - ID чата, сообщения которого нужно отметить как прочитанные
  /// Returns: Количество отмеченных сообщений
  /// Throws: Exception при ошибке отметки сообщений
  Future<int> markChatAsRead(int chatId) async {
    try {
      final res = await _client.post('/apiMes/messenger/chats/$chatId/read-all', {});

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['marked_count'] as int? ?? 0;
        } else {
          throw Exception('Не удалось отметить чат как прочитанный: ${data['message'] ?? 'Неизвестная ошибка'}');
        }
      } else {
        throw Exception('Не удалось отметить чат как прочитанный: ${res.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Не удалось отметить чат как прочитанный: ${e.response?.statusCode ?? 'Ошибка сети'}');
    } catch (e) {
      rethrow;
    }
  }

  /// Загружает медиа-файл (фото, видео) в чат
  ///
  /// Выполняет POST запрос для загрузки медиа-файла через multipart/form-data.
  ///
  /// [chatId] - ID чата, в который загружается файл
  /// [filePath] - путь к файлу на устройстве
  /// [messageType] - тип сообщения: 'photo' или 'video'
  /// [replyToId] - ID сообщения, на которое отвечаем (опционально)
  /// Returns: Объект Message с информацией о загруженном файле
  /// Throws: Exception при ошибке загрузки
  Future<Message> uploadMedia({
    required int chatId,
    required String filePath,
    required String messageType, // 'photo' or 'video'
    int? replyToId,
  }) async {
    try {
      final formData = FormData.fromMap({
        'message_type': messageType,
        'file': await MultipartFile.fromFile(filePath),
        if (replyToId != null) 'reply_to_id': replyToId,
      });

      final res = await _client.postFormData(
        '/apiMes/messenger/chats/$chatId/upload',
        formData,
      );

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        if (data['success'] == true && data['message'] != null) {
          return Message.fromJson(data['message'] as Map<String, dynamic>);
        } else {
          throw Exception('Не удалось загрузить файл: ${data['message'] ?? 'Неизвестная ошибка'}');
        }
      } else {
        throw Exception('Не удалось загрузить файл: ${res.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Не удалось загрузить файл: ${e.response?.statusCode ?? 'Ошибка сети'}');
    } catch (e) {
      rethrow;
    }
  }

  /// Загружает медиа-файл через Base64
  ///
  /// Выполняет POST запрос для загрузки медиа-файла через Base64 кодирование.
  ///
  /// [chatId] - ID чата, в который загружается файл
  /// [type] - тип файла: 'photo', 'video', или 'audio'
  /// [filename] - имя файла
  /// [base64Data] - Base64-кодированные данные файла
  /// [replyToId] - ID сообщения, на которое отвечаем (опционально)
  /// Returns: Объект Message с информацией о загруженном файле
  /// Throws: Exception при ошибке загрузки
  Future<Message> uploadMediaBase64({
    required int chatId,
    required String type, // 'photo', 'video', or 'audio'
    required String filename,
    required String base64Data,
    int? replyToId,
  }) async {
    try {
      final res = await _client.post('/apiMes/messenger/chats/$chatId/base64upload', {
        'type': type,
        'filename': filename,
        'data': base64Data,
        if (replyToId != null) 'reply_to_id': replyToId,
      });

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        if (data['success'] == true && data['message'] != null) {
          return Message.fromJson(data['message'] as Map<String, dynamic>);
        } else {
          throw Exception('Не удалось загрузить файл: ${data['message'] ?? 'Неизвестная ошибка'}');
        }
      } else {
        throw Exception('Не удалось загрузить файл: ${res.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Не удалось загрузить файл: ${e.response?.statusCode ?? 'Ошибка сети'}');
    } catch (e) {
      rethrow;
    }
  }

  /// Редактирует сообщение
  ///
  /// Выполняет PUT запрос для редактирования сообщения.
  /// Только текстовые сообщения могут быть отредактированы.
  ///
  /// [chatId] - ID чата
  /// [messageId] - ID сообщения для редактирования
  /// [content] - новый текст сообщения
  /// Returns: Обновленное сообщение
  /// Throws: Exception при ошибке редактирования
  Future<Message> editMessage(int chatId, int messageId, String content) async {
    try {
      final res = await _client.put(
        '/apiMes/messenger/chats/$chatId/messages/$messageId',
        {'text': content},
      );

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        final messageData = data['message'] as Map<String, dynamic>;
        return Message.fromJson(messageData);
      } else {
        throw Exception('Не удалось отредактировать сообщение: ${res.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Не удалось отредактировать сообщение: ${e.response?.statusCode ?? 'Ошибка сети'}');
    } catch (e) {
      rethrow;
    }
  }

  /// Удаляет сообщение
  ///
  /// Выполняет DELETE запрос для удаления сообщения.
  ///
  /// [chatId] - ID чата
  /// [messageId] - ID сообщения для удаления
  /// Throws: Exception при ошибке удаления
  Future<void> deleteMessage(int chatId, int messageId) async {
    try {
      final res = await _client.delete(
        '/apiMes/messenger/chats/$chatId/messages/$messageId',
      );

      if (res.statusCode != 200 && res.statusCode != 204) {
        throw Exception('Не удалось удалить сообщение: ${res.statusCode}');
      }
    } on DioException catch (e) {
      throw Exception('Не удалось удалить сообщение: ${e.response?.statusCode ?? 'Ошибка сети'}');
    } catch (e) {
      rethrow;
    }
  }
}
