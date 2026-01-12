import '../models/post.dart';
import '../models/comment.dart';
import '../models/poll.dart';
import '../models/complaint.dart';
import '../models/block_status.dart';

/// Интерфейс репозитория для операций с лентой новостей
///
/// Определяет контракт для работы с постами, комментариями и взаимодействием пользователей.
/// Обеспечивает доступ к данным ленты через стандартизированный интерфейс.
abstract class FeedRepository {
  /// Получает список постов для ленты новостей
  ///
  /// [page] - номер страницы для пагинации (начиная с 1)
  /// Returns: список постов для указанной страницы
  Future<List<Post>> fetchPosts({int page = 1});

  /// Ставит или убирает лайк с поста
  ///
  /// [postId] - идентификатор поста
  /// Returns: обновленный объект поста с новым состоянием лайка
  Future<Post> likePost(int postId);

  /// Получает комментарии к посту
  ///
  /// [postId] - идентификатор поста
  /// [page] - номер страницы для пагинации комментариев
  /// Returns: список комментариев к посту
  Future<List<Comment>> fetchComments(int postId, {int page = 1});

  /// Добавляет новый комментарий к посту
  ///
  /// [postId] - идентификатор поста
  /// [content] - текст комментария
  /// Returns: созданный объект комментария
  Future<Comment> addComment(int postId, String content);

  /// Удаляет комментарий
  ///
  /// [commentId] - идентификатор комментария для удаления
  Future<void> deleteComment(int commentId);

  /// Ставит лайк на комментарий
  ///
  /// [commentId] - идентификатор комментария
  Future<void> likeComment(int commentId);

  /// Убирает лайк с комментария
  ///
  /// [commentId] - идентификатор комментария
  Future<void> unlikeComment(int commentId);

  /// Голосует в опросе
  ///
  /// [pollId] - ID опроса
  /// [optionIds] - список ID выбранных вариантов ответа
  /// [isMultipleChoice] - флаг множественного выбора
  /// [hasExistingVotes] - флаг наличия существующих голосов
  /// Returns: Обновленный объект Poll
  Future<Poll> votePoll(int pollId, List<int> optionIds, {bool isMultipleChoice = false, bool hasExistingVotes = false});

  /// Создает жалобу на пост
  ///
  /// [complaintRequest] - данные жалобы
  /// Returns: ComplaintResponse с результатом создания жалобы
  Future<ComplaintResponse> submitComplaint(ComplaintRequest complaintRequest);
}

/// Интерфейс репозитория для операций с блокировкой пользователей
///
/// Предоставляет методы для управления черным списком пользователей.
abstract class UserBlockRepository {
  /// Блокирует пользователя
  ///
  /// [userId] - ID пользователя для блокировки
  /// Returns: BlockUserResponse с результатом блокировки
  Future<BlockUserResponse> blockUser(int userId);

  /// Разблокирует пользователя
  ///
  /// [userId] - ID пользователя для разблокировки
  /// Returns: UnblockUserResponse с результатом разблокировки
  Future<UnblockUserResponse> unblockUser(int userId);

  /// Проверяет статус блокировки пользователей
  ///
  /// [userIds] - список ID пользователей для проверки
  /// Returns: BlockStatusResponse со статусами блокировки
  Future<BlockStatusResponse> checkBlockStatus(List<int> userIds);

  /// Получает список заблокированных пользователей
  ///
  /// Returns: BlockedUsersResponse со списком заблокированных пользователей
  Future<BlockedUsersResponse> getBlockedUsers();

  /// Получает статистику черного списка
  ///
  /// Returns: BlacklistStatsResponse со статистикой черного списка
  Future<BlacklistStatsResponse> getBlacklistStats();
}

/// Интерфейс репозитория для операций с пользователями
///
/// Предоставляет доступ к данным пользователей, таким как онлайн статус.
abstract class UsersRepository {
  /// Получает список онлайн пользователей
  ///
  /// Returns: список пользователей с информацией об их онлайн статусе
  Future<List<Map<String, dynamic>>> fetchOnlineUsers();
}
