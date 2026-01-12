import 'api_client/dio_client.dart';
import '../features/feed/domain/models/block_status.dart';

/// Сервис для работы с пользователями через API
///
/// Предоставляет методы для получения информации о пользователях,
/// включая список онлайн-пользователей, поиск и управление черным списком.
class UsersService {
  final DioClient _client = DioClient();

  Future<List<dynamic>> fetchOnlineUsers({int limit = 100}) async {
    final res = await _client.get('/api/users/online', queryParameters: {'limit': limit});
    if (res.statusCode == 200) {
      return res.data as List<dynamic>;
    } else {
      throw Exception('Не удалось загрузить онлайн-пользователей');
    }
  }

  /// Поиск пользователей
  ///
  /// [query] - поисковый запрос
  /// [perPage] - количество результатов на странице (по умолчанию 5)
  /// Returns: Map с ключами 'users' (List'<'dynamic'>') и 'has_next' (bool)
  Future<Map<String, dynamic>> searchUsers(String query, {int perPage = 5}) async {
    try {
      final res = await _client.get(
        '/api/search/',
        queryParameters: {
          'q': query,
          'type': 'users',
          'per_page': perPage,
        },
      );

      if (res.statusCode == 200) {
        return res.data as Map<String, dynamic>;
      } else {
        throw Exception('Не удалось выполнить поиск пользователей');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Блокирует пользователя
  ///
  /// Отправляет POST запрос для добавления пользователя в черный список.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  ///
  /// [userId] - ID пользователя для блокировки
  /// Returns: BlockUserResponse с результатом блокировки
  Future<BlockUserResponse> blockUser(int userId) async {
    try {
      final res = await _client.post('/api/blacklist/add', {'user_id': userId}, headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return BlockUserResponse.fromJson(data);
      } else {
        throw Exception('Не удалось заблокировать пользователя: ${res.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Разблокирует пользователя
  ///
  /// Отправляет POST запрос для удаления пользователя из черного списка.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  ///
  /// [userId] - ID пользователя для разблокировки
  /// Returns: UnblockUserResponse с результатом разблокировки
  Future<UnblockUserResponse> unblockUser(int userId) async {
    try {
      final res = await _client.post('/api/blacklist/remove', {'user_id': userId}, headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return UnblockUserResponse.fromJson(data);
      } else {
        throw Exception('Не удалось разблокировать пользователя: ${res.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Проверяет статус блокировки пользователей
  ///
  /// Отправляет POST запрос для проверки статуса блокировки указанных пользователей.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  ///
  /// [userIds] - список ID пользователей для проверки
  /// Returns: BlockStatusResponse со статусами блокировки
  Future<BlockStatusResponse> checkBlockStatus(List<int> userIds) async {
    try {
      final res = await _client.post('/api/blacklist/check', {'user_ids': userIds}, headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return BlockStatusResponse.fromJson(data);
      } else {
        throw Exception('Не удалось проверить статус блокировки: ${res.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Получает список заблокированных пользователей
  ///
  /// Отправляет GET запрос для получения списка пользователей в черном списке.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  ///
  /// Returns: BlockedUsersResponse со списком заблокированных пользователей
  Future<BlockedUsersResponse> getBlockedUsers() async {
    try {
      final res = await _client.get('/api/blacklist/list', headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return BlockedUsersResponse.fromJson(data);
      } else {
        throw Exception('Не удалось получить список заблокированных пользователей: ${res.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Получает статистику черного списка
  ///
  /// Отправляет GET запрос для получения статистики блокировки пользователей.
  /// Включает необходимые заголовки Origin и Referer для корректной работы API.
  ///
  /// Returns: BlacklistStatsResponse со статистикой черного списка
  Future<BlacklistStatsResponse> getBlacklistStats() async {
    try {
      final res = await _client.get('/api/blacklist/stats', headers: {
        'Origin': 'https://k-connect.ru',
        'Referer': 'https://k-connect.ru/',
      });

      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        return BlacklistStatsResponse.fromJson(data);
      } else {
        throw Exception('Не удалось получить статистику черного списка: ${res.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
