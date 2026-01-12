import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../models/block_status.dart';
import '../repositories/feed_repository.dart';

/// Use case для блокировки пользователя
///
/// Отвечает за бизнес-логику блокировки пользователя.
/// Включает валидацию данных и обработку ошибок.
class BlockUserUseCase implements UseCase<BlockUserResponse, int> {
  /// Репозиторий для работы с данными блокировки
  final UserBlockRepository _userBlockRepository;

  /// Конструктор use case
  ///
  /// [userBlockRepository] - репозиторий для работы с блокировкой пользователей
  const BlockUserUseCase(this._userBlockRepository);

  /// Выполняет блокировку пользователя
  ///
  /// [params] - ID пользователя для блокировки
  /// Returns: Either с BlockUserResponse при успехе или Failure при ошибке
  @override
  Future<Either<Failure, BlockUserResponse>> call(int params) async {
    try {
      // Валидация входных данных
      if (params <= 0) {
        return Left(ValidationFailure(field: 'userId', message: 'Неверный ID пользователя'));
      }

      // Блокировка пользователя через репозиторий
      final result = await _userBlockRepository.blockUser(params);
      return Right(result);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}

/// Use case для разблокировки пользователя
///
/// Отвечает за бизнес-логику разблокировки пользователя.
/// Включает валидацию данных и обработку ошибок.
class UnblockUserUseCase implements UseCase<UnblockUserResponse, int> {
  /// Репозиторий для работы с данными блокировки
  final UserBlockRepository _userBlockRepository;

  /// Конструктор use case
  ///
  /// [userBlockRepository] - репозиторий для работы с блокировкой пользователей
  const UnblockUserUseCase(this._userBlockRepository);

  /// Выполняет разблокировку пользователя
  ///
  /// [params] - ID пользователя для разблокировки
  /// Returns: Either с UnblockUserResponse при успехе или Failure при ошибке
  @override
  Future<Either<Failure, UnblockUserResponse>> call(int params) async {
    try {
      // Валидация входных данных
      if (params <= 0) {
        return Left(ValidationFailure(field: 'userId', message: 'Неверный ID пользователя'));
      }

      // Разблокировка пользователя через репозиторий
      final result = await _userBlockRepository.unblockUser(params);
      return Right(result);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}

/// Use case для проверки статуса блокировки пользователей
///
/// Отвечает за бизнес-логику проверки статуса блокировки.
/// Включает валидацию данных и обработку ошибок.
class CheckBlockStatusUseCase implements UseCase<BlockStatusResponse, List<int>> {
  /// Репозиторий для работы с данными блокировки
  final UserBlockRepository _userBlockRepository;

  /// Конструктор use case
  ///
  /// [userBlockRepository] - репозиторий для работы с блокировкой пользователей
  const CheckBlockStatusUseCase(this._userBlockRepository);

  /// Выполняет проверку статуса блокировки пользователей
  ///
  /// [params] - список ID пользователей для проверки
  /// Returns: Either с BlockStatusResponse при успехе или Failure при ошибке
  @override
  Future<Either<Failure, BlockStatusResponse>> call(List<int> params) async {
    try {
      // Валидация входных данных
      if (params.isEmpty) {
        return Left(ValidationFailure(field: 'userIds', message: 'Список пользователей не может быть пустым'));
      }

      for (final userId in params) {
        if (userId <= 0) {
          return Left(ValidationFailure(field: 'userId', message: 'Неверный ID пользователя: $userId'));
        }
      }

      // Проверка статуса блокировки через репозиторий
      final result = await _userBlockRepository.checkBlockStatus(params);
      return Right(result);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}

/// Use case для получения списка заблокированных пользователей
///
/// Отвечает за бизнес-логику получения списка заблокированных пользователей.
/// Включает обработку ошибок.
class GetBlockedUsersUseCase implements UseCase<BlockedUsersResponse, NoParams> {
  /// Репозиторий для работы с данными блокировки
  final UserBlockRepository _userBlockRepository;

  /// Конструктор use case
  ///
  /// [userBlockRepository] - репозиторий для работы с блокировкой пользователей
  const GetBlockedUsersUseCase(this._userBlockRepository);

  /// Выполняет получение списка заблокированных пользователей
  ///
  /// [params] - NoParams (без параметров)
  /// Returns: Either с BlockedUsersResponse при успехе или Failure при ошибке
  @override
  Future<Either<Failure, BlockedUsersResponse>> call(NoParams params) async {
    try {
      // Получение списка заблокированных пользователей через репозиторий
      final result = await _userBlockRepository.getBlockedUsers();
      return Right(result);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}

/// Use case для получения статистики черного списка
///
/// Отвечает за бизнес-логику получения статистики черного списка.
/// Включает обработку ошибок.
class GetBlacklistStatsUseCase implements UseCase<BlacklistStatsResponse, NoParams> {
  /// Репозиторий для работы с данными блокировки
  final UserBlockRepository _userBlockRepository;

  /// Конструктор use case
  ///
  /// [userBlockRepository] - репозиторий для работы с блокировкой пользователей
  const GetBlacklistStatsUseCase(this._userBlockRepository);

  /// Выполняет получение статистики черного списка
  ///
  /// [params] - NoParams (без параметров)
  /// Returns: Either с BlacklistStatsResponse при успехе или Failure при ошибке
  @override
  Future<Either<Failure, BlacklistStatsResponse>> call(NoParams params) async {
    try {
      // Получение статистики черного списка через репозиторий
      final result = await _userBlockRepository.getBlacklistStats();
      return Right(result);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
