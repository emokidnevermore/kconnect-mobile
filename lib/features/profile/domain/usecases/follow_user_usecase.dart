import 'package:kconnect_mobile/features/profile/domain/repositories/profile_repository.dart';

/// Use case для управления подписками на пользователей
///
/// Предоставляет функциональность для подписки, отписки и управления
/// уведомлениями от подписанных пользователей.
class FollowUserUseCase {
  final ProfileRepository _repository;

  FollowUserUseCase(this._repository);

  /// Выполняет подписку на пользователя
  ///
  /// [followedId] - ID пользователя для подписки
  Future<Map<String, dynamic>> follow(int followedId) => _repository.followUser(followedId);

  /// Выполняет отписку от пользователя
  ///
  /// [followedId] - ID пользователя для отписки
  Future<Map<String, dynamic>> unfollow(int followedId) => _repository.unfollowUser(followedId);

  /// Управляет уведомлениями от подписанного пользователя
  ///
  /// [followedUsername] - имя пользователя, от которого управляются уведомления
  /// [enabled] - включить или отключить уведомления
  Future<void> toggleNotifications(String followedUsername, bool enabled) =>
    _repository.toggleNotifications(followedUsername, enabled);
}
