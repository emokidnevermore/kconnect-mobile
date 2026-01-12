/// Сервис для работы с постами через API
///
/// Управляет всеми операциями с постами: загрузка, лайки, комментарии.
/// Поддерживает повторные попытки и обработку ошибок сети.
library;

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../features/music/domain/models/track.dart';
import '../features/feed/domain/models/post.dart';
import '../features/feed/domain/models/complaint.dart';
import 'api_client/dio_client.dart';

/// Сервис API постов
class PostsService {
  /// HTTP клиент для выполнения запросов
  final DioClient _client = DioClient();

  /// Получает список постов ленты новостей
  ///
  /// Выполняет GET запрос к API для получения постов с пагинацией.
  /// Поддерживает сортировку по времени создания и включение всех типов постов.
  Future<Map<String, dynamic>> fetchPosts({int page = 1, int perPage = 20}) async {
    return _retryRequest(() async {
      final queryParams = {
        'page': page,
        'per_page': perPage,
        'sort': 'newest',
        'include_all': 'true',
      };

      final res = await _client.get('/api/posts/feed', queryParameters: queryParams);
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Не удалось загрузить посты: ${res.statusCode}');
      }
    });
  }

  /// Ставит лайк на пост
  ///
  /// Отправляет POST запрос для установки лайка на указанный пост.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  Future<Map<String, dynamic>> likePost(int postId) async {
    return _retryRequest(() async {
      final res = await _client.post('/api/posts/$postId/like', null, headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Не удалось поставить лайк на пост: ${res.statusCode}');
      }
    });
  }

  /// Получает комментарии к посту
  ///
  /// Выполняет GET запрос для получения списка комментариев к указанному посту.
  /// Поддерживает пагинацию для загрузки комментариев порциями.
  Future<Map<String, dynamic>> fetchComments(int postId, {int page = 1, int perPage = 20}) async {
    return _retryRequest(() async {
      final res = await _client.get('/api/posts/$postId/comments', queryParameters: {
        'page': page,
        'per_page': perPage,
      });
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Не удалось загрузить комментарии: ${res.statusCode}');
      }
    });
  }

  /// Добавляет новый комментарий к посту
  ///
  /// Отправляет POST запрос для создания нового комментария.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  Future<Map<String, dynamic>> addComment(int postId, String text) async {
    return _retryRequest(() async {
      final res = await _client.post('/api/posts/$postId/comments', {'content': text}, headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Не удалось добавить комментарий: ${res.statusCode}');
      }
    });
  }

  /// Удаляет комментарий
  ///
  /// Отправляет DELETE запрос для удаления указанного комментария.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    return _retryRequest(() async {
      final res = await _client.delete('/api/comments/$commentId', headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Не удалось удалить комментарий: ${res.statusCode}');
      }
    });
  }

  /// Ставит лайк на комментарий
  ///
  /// Отправляет POST запрос для установки лайка на указанный комментарий.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  Future<Map<String, dynamic>> likeComment(int commentId) async {
    return _retryRequest(() async {
      final res = await _client.post('/api/comments/$commentId/like', {}, headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Не удалось поставить лайк на комментарий: ${res.statusCode}');
      }
    });
  }

  /// Убирает лайк с комментария
  ///
  /// Отправляет POST запрос для снятия лайка с указанного комментария.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  Future<Map<String, dynamic>> unlikeComment(int commentId) async {
    return _retryRequest(() async {
      final res = await _client.post('/api/comments/$commentId/unlike', {}, headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Не удалось убрать лайк с комментария: ${res.statusCode}');
      }
    });
  }

  /// Создает новый пост
  ///
  /// Отправляет POST запрос для создания нового поста с текстом, изображениями, видео, музыкой и опросом.
  /// Использует multipart/form-data для отправки файлов и JSON данных.
  /// НЕ использует повторные попытки, так как создание поста - не идемпотентная операция.
  Future<Map<String, dynamic>> createPost({
    required String content,
    required bool isNsfw,
    required List<String> imagePaths,
    String? videoPath,
    String? videoThumbnailPath,
    required List<Track> musicTracks,
    String? pollQuestion,
    List<String> pollOptions = const [],
    bool pollIsAnonymous = false,
    bool pollIsMultiple = false,
    int? pollExpiresInDays,
  }) async {
    // Создаем FormData для multipart запроса
    final formData = FormData();

    // Добавляем текстовые поля
    formData.fields.add(MapEntry('content', content));
    formData.fields.add(MapEntry('is_nsfw', isNsfw.toString()));

    debugPrint('PostsService: Creating post with:');
    debugPrint('  Content: "$content"');
    debugPrint('  Is NSFW: $isNsfw');
    debugPrint('  Image paths count: ${imagePaths.length}');
    debugPrint('  Video path: ${videoPath ?? "none"}');
    debugPrint('  Video thumbnail path: ${videoThumbnailPath ?? "none"}');
    debugPrint('  Music tracks count: ${musicTracks.length}');
    debugPrint('  Poll question: ${pollQuestion ?? "none"}');
    debugPrint('  Poll options count: ${pollOptions.length}');
    debugPrint('  Poll is anonymous: $pollIsAnonymous');
    debugPrint('  Poll is multiple: $pollIsMultiple');
    debugPrint('  Poll expires in days: ${pollExpiresInDays ?? "none"}');

    // Добавляем изображения как файлы
    for (var i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      debugPrint('  Adding image $i: $imagePath');

      try {
        final multipartFile = await MultipartFile.fromFile(
          imagePath,
          filename: 'image_$i.${imagePath.split('.').last}',
        );
        formData.files.add(MapEntry('images[$i]', multipartFile));
        debugPrint('  Image $i added successfully');
      } catch (e) {
        debugPrint('  Error adding image $i: $e');
        rethrow; // Прерываем выполнение при ошибке с файлами
      }
    }

    // Добавляем видео файл
    if (videoPath != null) {
      debugPrint('  Adding video: $videoPath');
      try {
        final videoFile = await MultipartFile.fromFile(
          videoPath,
          filename: 'video.${videoPath.split('.').last}',
        );
        formData.files.add(MapEntry('video', videoFile));
        debugPrint('  Video added successfully');
      } catch (e) {
        debugPrint('  Error adding video: $e');
        rethrow; // Прерываем выполнение при ошибке с файлами
      }
    }

    // Добавляем превью видео (thumbnail)
    if (videoThumbnailPath != null) {
      debugPrint('  Adding video thumbnail: $videoThumbnailPath');
      try {
        final thumbnailFile = await MultipartFile.fromFile(
          videoThumbnailPath,
          filename: 'video_thumbnail.jpg',
        );
        formData.files.add(MapEntry('video_thumbnail', thumbnailFile));
        debugPrint('  Video thumbnail added successfully');
      } catch (e) {
        debugPrint('  Error adding video thumbnail: $e');
        rethrow; // Прерываем выполнение при ошибке с файлами
      }
    }

    // Добавляем музыку как JSON массив (API ожидает массив под ключом 'music')
    if (musicTracks.isNotEmpty) {
      final musicList = musicTracks.map((track) => {
        'id': track.id,
        'title': track.title,
        'artist': track.artist,
        'duration': (track.durationMs / 1000).round(),
        'file_path': track.filePath,
        'cover_path': track.coverPath,
      }).toList();

      formData.fields.add(MapEntry('music', jsonEncode(musicList)));
      debugPrint('  Added music array with ${musicTracks.length} tracks');
    }

    // Добавляем данные опроса
    if (pollQuestion != null && pollQuestion.isNotEmpty && pollOptions.isNotEmpty) {
      formData.fields.add(MapEntry('poll_question', pollQuestion));
      formData.fields.add(MapEntry('poll_options', jsonEncode(pollOptions)));
      formData.fields.add(MapEntry('poll_is_anonymous', pollIsAnonymous.toString()));
      formData.fields.add(MapEntry('poll_is_multiple', pollIsMultiple.toString()));
      if (pollExpiresInDays != null) {
        formData.fields.add(MapEntry('poll_expires_in_days', pollExpiresInDays.toString()));
      }
      debugPrint('  Added poll data');
    }

    debugPrint('PostsService: FormData fields count: ${formData.fields.length}');
    debugPrint('PostsService: FormData files count: ${formData.files.length}');

    try {
      final res = await _client.postFormData('/api/posts/create', formData, headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });

      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data as Map<String, dynamic>;
        debugPrint('PostsService: Post created successfully');
        return data;
      } else {
        // Проверяем, есть ли в теле ответа информация об ошибке
        final errorMessage = res.data is Map<String, dynamic>
            ? res.data['message'] ?? res.data['error'] ?? 'Неизвестная ошибка'
            : 'Неизвестная ошибка';
        throw Exception('Не удалось создать пост: ${res.statusCode} - $errorMessage');
      }
    } on DioException catch (e) {
      debugPrint('PostsService: DioException during post creation: ${e.message}');
      if (e.response?.statusCode == 422) {
        // Валидационная ошибка - не повторяем
        final errorData = e.response?.data;
        final errorMessage = errorData is Map<String, dynamic>
            ? errorData['message'] ?? errorData['error'] ?? 'Ошибка валидации'
            : 'Ошибка валидации';
        throw Exception('Ошибка валидации: $errorMessage');
      }
      rethrow;
    } catch (e) {
      debugPrint('PostsService: Unexpected error during post creation: $e');
      rethrow;
    }
  }

  /// Репостит пост
  ///
  /// Отправляет POST запрос для создания репоста указанного поста.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  ///
  /// [postId] - ID поста для репоста
  /// [text] - текст репоста (может быть пустым)
  /// Returns: Map с данными созданного репоста
  Future<Map<String, dynamic>> repostPost(int postId, String text) async {
    return _retryRequest(() async {
      final res = await _client.post('/api/posts/$postId/repost', {'text': text}, headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Не удалось сделать репост: ${res.statusCode}');
      }
    });
  }

  /// Голосует в опросе или отменяет голос
  ///
  /// Отправляет POST запрос для голосования в опросе или DELETE для отмены голоса.
  /// Для множественного выбора сначала отменяет предыдущие голоса DELETE запросом.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  ///
  /// [pollId] - ID опроса
  /// [optionIds] - Список ID выбранных вариантов ответа (пустой список для отмены голоса)
  /// [isMultipleChoice] - Флаг множественного выбора
  /// [hasExistingVotes] - Флаг наличия существующих голосов
  /// Returns: Map с обновленными данными опроса
  Future<Map<String, dynamic>> votePoll(int pollId, List<int> optionIds, {bool isMultipleChoice = false, bool hasExistingVotes = false}) async {
    return _retryRequest(() async {
      // Если optionIds пустой, это запрос на отмену голоса
      if (optionIds.isEmpty) {
        final res = await _client.delete('/api/polls/$pollId/vote', headers: {
          'Origin': 'https://k-connect.ru',
          'Referer': 'https://k-connect.ru/',
        });
        if (res.statusCode == 200) {
          final data = res.data as Map<String, dynamic>;
          return data;
        } else {
          throw Exception('Не удалось отменить голос: ${res.statusCode}');
        }
      }

      // Для множественного выбора с существующими голосами сначала отменяем предыдущие голоса
      if (isMultipleChoice && hasExistingVotes) {
        try {
          await _client.delete('/api/polls/$pollId/vote', headers: {
            'Origin': 'https://k-connect.ru',
            'Referer': 'https://k-connect.ru/',
          });
        } catch (e) {
          // Игнорируем ошибки отмены голосов, продолжаем с новым голосованием
        }
      }

      final res = await _client.post('/api/polls/$pollId/vote', {'option_ids': optionIds}, headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data as Map<String, dynamic>;
        return data;
      } else {
        throw Exception('Не удалось проголосовать: ${res.statusCode}');
      }
    });
  }

  /// Получает пост по ID
  ///
  /// Выполняет GET запрос для получения данных поста по его ID.
  ///
  /// [postId] - ID поста для загрузки
  /// Returns: Объект Post
  Future<Post> fetchPostById(int postId) async {
    return _retryRequest(() async {
      final res = await _client.get('/api/posts/$postId', headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        // API может возвращать пост в разных форматах
        Map<String, dynamic> postData;
        if (data['post'] != null) {
          postData = data['post'] as Map<String, dynamic>;
        } else if (data['success'] == true && data['post'] != null) {
          postData = data['post'] as Map<String, dynamic>;
        } else {
          postData = data;
        }
        return Post.fromJson(postData);
      } else if (res.statusCode == 404) {
        // Специально бросаем исключение для 404, так как validateStatus считает его успешным
        throw Exception('Не удалось загрузить пост: 404');
      } else {
        throw Exception('Не удалось загрузить пост: ${res.statusCode}');
      }
    });
  }

  /// Создает жалобу на пост
  ///
  /// Отправляет POST запрос для создания жалобы на указанный пост.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  ///
  /// [complaintRequest] - данные жалобы
  /// Returns: ComplaintResponse с результатом создания жалобы
  Future<ComplaintResponse> submitComplaint(ComplaintRequest complaintRequest) async {
    return _retryRequest(() async {
      final res = await _client.post('/api/complaints', complaintRequest.toJson(), headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data as Map<String, dynamic>;
        return ComplaintResponse.fromJson(data);
      } else {
        throw Exception('Не удалось отправить жалобу: ${res.statusCode}');
      }
    });
  }

  /// Выполняет запрос с повторными попытками
  ///
  /// Реализует механизм повторных попыток для сетевых запросов.
  /// При ошибках DioException или других исключениях выполняет повторные попытки
  /// с экспоненциальной задержкой (1, 2, 4 секунды и т.д.).
  /// НЕ повторяет запросы при 404 ошибке (пост удален).
  Future<T> _retryRequest<T>(Future<T> Function() request, {int maxRetries = 3}) async {
    int retries = 0;
    while (retries <= maxRetries) {
      try {
        return await request();
      } on DioException catch (e) {
        // Не повторяем при 404 ошибке (пост удален)
        if (e.response?.statusCode == 404) {
          throw Exception('Не удалось загрузить пост: 404');
        }

        retries++;
        if (retries > maxRetries) {
          throw Exception('Не удалось выполнить запрос после $maxRetries попыток: ${e.response?.statusCode ?? 'Ошибка сети'}');
        }
        final delay = Duration(seconds: 1 << (retries - 1));
        await Future.delayed(delay);
      } catch (e) {
        // Не повторяем при 404 ошибке (пост удален) - проверяем сообщение об ошибке
        if (e.toString().contains('404')) {
          rethrow;
        }

        retries++;
        if (retries > maxRetries) {
          rethrow;
        }
        final delay = Duration(seconds: 1 << (retries - 1));
        await Future.delayed(delay);
      }
    }
    throw Exception('Логика повторных попыток не сработала');
  }
}
