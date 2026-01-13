/// Реализация репозитория данных для системы ленты новостей
///
/// Предоставляет унифицированный интерфейс для работы с данными постов,
/// комментариев и онлайн-пользователей. Делегирует выполнение операций
/// сервисам PostsService и UsersService. Реализует паттерн Repository
/// для абстракции работы с внешними источниками данных.
library;

import '../../../../../services/posts_service.dart';
import '../../../../../services/users_service.dart';
import '../../domain/models/post.dart';
import '../../domain/models/comment.dart';
import '../../domain/models/poll.dart';
import '../../domain/models/complaint.dart';
import '../../domain/models/block_status.dart';
import '../../domain/repositories/feed_repository.dart';

/// Реализация репозитория ленты новостей
///
/// Содержит бизнес-логику для работы с постами, комментариями и пользователями.
/// Преобразует данные из внешних сервисов в объекты доменной модели.
class FeedRepositoryImpl implements FeedRepository {
  /// Сервис для работы с API постов
  final PostsService _postsService;

  /// Конструктор репозитория постов
  ///
  /// [postsService] - сервис для выполнения операций с постами
  FeedRepositoryImpl(this._postsService);

  /// Получает список постов с пагинацией
  ///
  /// Выполняет запрос к API для получения постов указанной страницы.
  /// Преобразует полученные данные в объекты Post.
  ///
  /// [page] - номер страницы для загрузки (по умолчанию 1)
  /// Returns: Список объектов Post
  /// Throws: Exception при ошибке загрузки постов
  @override
  Future<List<Post>> fetchPosts({int page = 1}) async {
    try {
      final data = await _postsService.fetchPosts(page: page);
      final postsData = List<Map<String, dynamic>>.from(data['posts'] ?? []);
      return postsData.map((json) => Post.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить посты: $e');
    }
  }

  /// Ставит лайк на пост
  ///
  /// Отправляет запрос на сервер для изменения статуса лайка поста.
  /// Возвращает обновленный объект Post с актуальными счетчиками.
  ///
  /// [postId] - ID поста для лайка
  /// Returns: Обновленный объект Post
  /// Throws: Exception при ошибке установки лайка
  @override
  Future<Post> likePost(int postId) async {
    try {
      final data = await _postsService.likePost(postId);
      return Post.fromJson(data);
    } catch (e) {
      throw Exception('Не удалось поставить лайк на пост: $e');
    }
  }

  /// Получает комментарии к посту
  ///
  /// Загружает комментарии для указанного поста с поддержкой пагинации.
  /// Преобразует данные в объекты Comment.
  ///
  /// [postId] - ID поста, комментарии которого нужно получить
  /// [page] - номер страницы комментариев (по умолчанию 1)
  /// Returns: Список объектов Comment
  /// Throws: Exception при ошибке загрузки комментариев
  @override
  Future<List<Comment>> fetchComments(int postId, {int page = 1}) async {
    try {
      final data = await _postsService.fetchComments(postId, page: page);
      final commentsData = List<Map<String, dynamic>>.from(data['comments'] ?? []);
      return commentsData.map((json) => Comment.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Не удалось загрузить комментарии: $e');
    }
  }

  /// Добавляет новый комментарий к посту
  ///
  /// Отправляет запрос на создание нового комментария.
  /// Возвращает созданный объект Comment.
  ///
  /// [postId] - ID поста, к которому добавляется комментарий
  /// [content] - текст комментария
  /// Returns: Созданный объект Comment
  /// Throws: Exception при ошибке добавления комментария
  @override
  Future<Comment> addComment(int postId, String content) async {
    try {
      final data = await _postsService.addComment(postId, content);
      return Comment.fromJson(data['comment'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Не удалось добавить комментарий: $e');
    }
  }

  /// Добавляет ответ на комментарий
  ///
  /// Отправляет запрос на создание ответа на комментарий.
  /// Возвращает созданный объект Comment.
  ///
  /// [commentId] - ID комментария, на который добавляется ответ
  /// [content] - текст ответа
  /// [parentReplyId] - ID родительского ответа (для вложенных ответов)
  /// Returns: Созданный объект Comment
  /// Throws: Exception при ошибке добавления ответа
  @override
  Future<Comment> addReply(int commentId, String content, {int? parentReplyId}) async {
    try {
      final data = await _postsService.addReply(commentId, content, parentReplyId: parentReplyId);
      return Comment.fromJson(data['reply'] as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Не удалось добавить ответ на комментарий: $e');
    }
  }

  /// Удаляет комментарий
  ///
  /// Отправляет запрос на удаление комментария по его ID.
  ///
  /// [commentId] - ID комментария для удаления
  /// Throws: Exception при ошибке удаления комментария
  @override
  Future<void> deleteComment(int commentId) async {
    try {
      await _postsService.deleteComment(commentId);
    } catch (e) {
      throw Exception('Не удалось удалить комментарий: $e');
    }
  }

  /// Ставит лайк на комментарий
  ///
  /// Отправляет запрос на установку лайка комментарию.
  ///
  /// [commentId] - ID комментария для лайка
  /// Throws: Exception при ошибке установки лайка
  @override
  Future<void> likeComment(int commentId) async {
    try {
      await _postsService.likeComment(commentId);
    } catch (e) {
      throw Exception('Не удалось поставить лайк на комментарий: $e');
    }
  }

  /// Убирает лайк с комментария
  ///
  /// Отправляет запрос на снятие лайка с комментария.
  ///
  /// [commentId] - ID комментария для снятия лайка
  /// Throws: Exception при ошибке снятия лайка
  @override
  Future<void> unlikeComment(int commentId) async {
    try {
      await _postsService.unlikeComment(commentId);
    } catch (e) {
      throw Exception('Не удалось убрать лайк с комментария: $e');
    }
  }

  /// Голосует в опросе
  ///
  /// Отправляет запрос на голосование в опросе.
  /// Возвращает обновленный объект опроса.
  ///
  /// [pollId] - ID опроса
  /// [optionIds] - список ID выбранных вариантов ответа
  /// Returns: Обновленный объект Poll
  /// Throws: Exception при ошибке голосования
  @override
  Future<Poll> votePoll(int pollId, List<int> optionIds, {bool isMultipleChoice = false, bool hasExistingVotes = false}) async {
    try {
      final data = await _postsService.votePoll(pollId, optionIds, isMultipleChoice: isMultipleChoice, hasExistingVotes: hasExistingVotes);
      if (data.containsKey('poll')) {
        final pollData = data['poll'] as Map<String, dynamic>;
        return Poll.fromJson(pollData);
      }
      throw Exception('Неверный формат ответа от API');
    } catch (e) {
      throw Exception('Не удалось проголосовать: $e');
    }
  }

  /// Создает жалобу на пост
  ///
  /// Отправляет запрос на создание жалобы на указанный пост.
  /// Возвращает результат создания жалобы.
  ///
  /// [complaintRequest] - данные жалобы
  /// Returns: ComplaintResponse с результатом создания жалобы
  /// Throws: Exception при ошибке создания жалобы
  @override
  Future<ComplaintResponse> submitComplaint(ComplaintRequest complaintRequest) async {
    try {
      return await _postsService.submitComplaint(complaintRequest);
    } catch (e) {
      throw Exception('Не удалось отправить жалобу: $e');
    }
  }

}

/// Реализация репозитория пользователей
///
/// Предоставляет доступ к данным пользователей, включая список онлайн-пользователей.
/// Делегирует выполнение операций сервису UsersService.
class UsersRepositoryImpl implements UsersRepository {
  /// Сервис для работы с API пользователей
  final UsersService _usersService;

  /// Конструктор репозитория пользователей
  ///
  /// [usersService] - сервис для выполнения операций с пользователями
  UsersRepositoryImpl(this._usersService);

  /// Получает список онлайн-пользователей
  ///
  /// Выполняет запрос к API для получения списка пользователей,
  /// которые находятся в сети в данный момент.
  ///
  /// Returns: Список данных онлайн-пользователей в формате Map
  /// Throws: Exception при ошибке загрузки пользователей
  @override
  Future<List<Map<String, dynamic>>> fetchOnlineUsers() async {
    try {
      final data = await _usersService.fetchOnlineUsers();
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception('Не удалось загрузить онлайн-пользователей: $e');
    }
  }
}

/// Реализация репозитория блокировки пользователей
///
/// Предоставляет методы для управления черным списком пользователей.
/// Делегирует выполнение операций сервису UsersService.
class UserBlockRepositoryImpl implements UserBlockRepository {
  /// Сервис для работы с API пользователей
  final UsersService _usersService;

  /// Конструктор репозитория блокировки пользователей
  ///
  /// [usersService] - сервис для выполнения операций с пользователями
  UserBlockRepositoryImpl(this._usersService);

  /// Блокирует пользователя
  ///
  /// Отправляет запрос на добавление пользователя в черный список.
  ///
  /// [userId] - ID пользователя для блокировки
  /// Returns: BlockUserResponse с результатом блокировки
  /// Throws: Exception при ошибке блокировки
  @override
  Future<BlockUserResponse> blockUser(int userId) async {
    try {
      return await _usersService.blockUser(userId);
    } catch (e) {
      throw Exception('Не удалось заблокировать пользователя: $e');
    }
  }

  /// Разблокирует пользователя
  ///
  /// Отправляет запрос на удаление пользователя из черного списка.
  ///
  /// [userId] - ID пользователя для разблокировки
  /// Returns: UnblockUserResponse с результатом разблокировки
  /// Throws: Exception при ошибке разблокировки
  @override
  Future<UnblockUserResponse> unblockUser(int userId) async {
    try {
      return await _usersService.unblockUser(userId);
    } catch (e) {
      throw Exception('Не удалось разблокировать пользователя: $e');
    }
  }

  /// Проверяет статус блокировки пользователей
  ///
  /// Отправляет запрос на проверку статуса блокировки указанных пользователей.
  ///
  /// [userIds] - список ID пользователей для проверки
  /// Returns: BlockStatusResponse со статусами блокировки
  /// Throws: Exception при ошибке проверки статуса
  @override
  Future<BlockStatusResponse> checkBlockStatus(List<int> userIds) async {
    try {
      return await _usersService.checkBlockStatus(userIds);
    } catch (e) {
      throw Exception('Не удалось проверить статус блокировки: $e');
    }
  }

  /// Получает список заблокированных пользователей
  ///
  /// Отправляет запрос на получение списка пользователей в черном списке.
  ///
  /// Returns: BlockedUsersResponse со списком заблокированных пользователей
  /// Throws: Exception при ошибке получения списка
  @override
  Future<BlockedUsersResponse> getBlockedUsers() async {
    try {
      return await _usersService.getBlockedUsers();
    } catch (e) {
      throw Exception('Не удалось получить список заблокированных пользователей: $e');
    }
  }

  /// Получает статистику черного списка
  ///
  /// Отправляет запрос на получение статистики блокировки пользователей.
  ///
  /// Returns: BlacklistStatsResponse со статистикой черного списка
  /// Throws: Exception при ошибке получения статистики
  @override
  Future<BlacklistStatsResponse> getBlacklistStats() async {
    try {
      return await _usersService.getBlacklistStats();
    } catch (e) {
      throw Exception('Не удалось получить статистику черного списка: $e');
    }
  }
}
