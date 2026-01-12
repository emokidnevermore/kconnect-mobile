/// Модель данных для статуса блокировки пользователей
///
/// Содержит информацию о блокировке пользователей в черном списке.
library;

import 'package:equatable/equatable.dart';

/// Статус блокировки пользователя
class BlockStatus extends Equatable {
  final int userId;
  final bool isBlocked;

  const BlockStatus({
    required this.userId,
    required this.isBlocked,
  });

  @override
  List<Object> get props => [userId, isBlocked];

  /// Создать из JSON ответа API
  factory BlockStatus.fromJson(Map<String, dynamic> json) {
    return BlockStatus(
      userId: json['user_id'] as int? ?? 0,
      isBlocked: json['is_blocked'] as bool? ?? false,
    );
  }

  /// Преобразовать в JSON
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'is_blocked': isBlocked,
    };
  }
}

/// Ответ API на проверку статуса блокировки
class BlockStatusResponse extends Equatable {
  final Map<int, bool> blockedStatus;
  final bool success;

  const BlockStatusResponse({
    required this.blockedStatus,
    required this.success,
  });

  @override
  List<Object> get props => [blockedStatus, success];

  /// Создать из JSON ответа API
  factory BlockStatusResponse.fromJson(Map<String, dynamic> json) {
    final blockedStatus = <int, bool>{};
    final statusMap = json['blocked_status'] as Map<String, dynamic>? ?? {};

    statusMap.forEach((key, value) {
      final userId = int.tryParse(key);
      if (userId != null && value is bool) {
        blockedStatus[userId] = value;
      }
    });

    return BlockStatusResponse(
      blockedStatus: blockedStatus,
      success: json['success'] as bool? ?? false,
    );
  }
}

/// Ответ API на блокировку/разблокировку пользователя
class BlockUserResponse extends Equatable {
  final int userId;
  final String userName;
  final String userPhoto;
  final String userUsername;
  final String message;
  final bool success;

  const BlockUserResponse({
    required this.userId,
    required this.userName,
    required this.userPhoto,
    required this.userUsername,
    required this.message,
    required this.success,
  });

  @override
  List<Object> get props => [userId, userName, userPhoto, userUsername, message, success];

  /// Создать из JSON ответа API
  factory BlockUserResponse.fromJson(Map<String, dynamic> json) {
    final blockedUser = json['blocked_user'] as Map<String, dynamic>? ?? {};

    return BlockUserResponse(
      userId: blockedUser['id'] as int? ?? 0,
      userName: blockedUser['name'] as String? ?? '',
      userPhoto: blockedUser['photo'] as String? ?? '',
      userUsername: blockedUser['username'] as String? ?? '',
      message: json['message'] as String? ?? '',
      success: json['success'] as bool? ?? false,
    );
  }
}

/// Ответ API на разблокировку пользователя
class UnblockUserResponse extends Equatable {
  final String message;
  final bool success;

  const UnblockUserResponse({
    required this.message,
    required this.success,
  });

  @override
  List<Object> get props => [message, success];

  /// Создать из JSON ответа API
  factory UnblockUserResponse.fromJson(Map<String, dynamic> json) {
    return UnblockUserResponse(
      message: json['message'] as String? ?? '',
      success: json['success'] as bool? ?? false,
    );
  }
}

/// Заблокированный пользователь
class BlockedUser extends Equatable {
  final int id;
  final String name;
  final String username;
  final String photo;
  final String? achievement;
  final int? verification;

  const BlockedUser({
    required this.id,
    required this.name,
    required this.username,
    required this.photo,
    this.achievement,
    this.verification,
  });

  @override
  List<Object?> get props => [id, name, username, photo, achievement, verification];

  /// Создать из JSON ответа API
  factory BlockedUser.fromJson(Map<String, dynamic> json) {
    return BlockedUser(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      photo: json['photo'] as String? ?? '',
      achievement: json['achievement'] as String?,
      verification: json['verification'] as int?,
    );
  }
}

/// Ответ API на получение списка заблокированных пользователей
class BlockedUsersResponse extends Equatable {
  final List<BlockedUser> blockedUsers;
  final Map<String, dynamic> pagination;
  final bool success;

  const BlockedUsersResponse({
    required this.blockedUsers,
    required this.pagination,
    required this.success,
  });

  @override
  List<Object> get props => [blockedUsers, pagination, success];

  /// Создать из JSON ответа API
  factory BlockedUsersResponse.fromJson(Map<String, dynamic> json) {
    final blockedUsersJson = json['blocked_users'] as List<dynamic>? ?? [];
    final blockedUsers = blockedUsersJson
        .map((userJson) => BlockedUser.fromJson(userJson as Map<String, dynamic>))
        .toList();

    return BlockedUsersResponse(
      blockedUsers: blockedUsers,
      pagination: json['pagination'] as Map<String, dynamic>? ?? {},
      success: json['success'] as bool? ?? false,
    );
  }
}

/// Статистика черного списка
class BlacklistStats extends Equatable {
  final int totalBlocked;
  final int totalBlockedBy;

  const BlacklistStats({
    required this.totalBlocked,
    required this.totalBlockedBy,
  });

  @override
  List<Object> get props => [totalBlocked, totalBlockedBy];

  /// Создать из JSON ответа API
  factory BlacklistStats.fromJson(Map<String, dynamic> json) {
    return BlacklistStats(
      totalBlocked: json['total_blocked'] as int? ?? 0,
      totalBlockedBy: json['total_blocked_by'] as int? ?? 0,
    );
  }
}

/// Ответ API на получение статистики черного списка
class BlacklistStatsResponse extends Equatable {
  final BlacklistStats stats;
  final bool success;

  const BlacklistStatsResponse({
    required this.stats,
    required this.success,
  });

  @override
  List<Object> get props => [stats, success];

  /// Создать из JSON ответа API
  factory BlacklistStatsResponse.fromJson(Map<String, dynamic> json) {
    return BlacklistStatsResponse(
      stats: BlacklistStats.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
      success: json['success'] as bool? ?? false,
    );
  }
}
