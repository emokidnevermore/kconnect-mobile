import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../models/complaint.dart';
import '../repositories/feed_repository.dart';

/// Use case для создания жалобы на пост
///
/// Отвечает за бизнес-логику создания жалобы на пост.
/// Включает валидацию данных и обработку ошибок.
class ReportPostUseCase implements UseCase<ComplaintResponse, ComplaintRequest> {
  /// Репозиторий для работы с данными постов
  final FeedRepository _feedRepository;

  /// Конструктор use case
  ///
  /// [feedRepository] - репозиторий для работы с данными постов
  const ReportPostUseCase(this._feedRepository);

  /// Выполняет создание жалобы на пост
  ///
  /// [params] - параметры жалобы (ComplaintRequest)
  /// Returns: Either с ComplaintResponse при успехе или Failure при ошибке
  @override
  Future<Either<Failure, ComplaintResponse>> call(ComplaintRequest params) async {
    try {
      // Валидация входных данных
      if (params.targetType.isEmpty) {
        return Left(ValidationFailure(field: 'targetType', message: 'Тип цели жалобы не может быть пустым'));
      }

      if (params.reason.isEmpty) {
        return Left(ValidationFailure(field: 'reason', message: 'Причина жалобы не может быть пустой'));
      }

      if (params.targetId <= 0) {
        return Left(ValidationFailure(field: 'targetId', message: 'Неверный ID цели жалобы'));
      }

      // Отправка жалобы через репозиторий
      final result = await _feedRepository.submitComplaint(params);
      return Right(result);
    } on Exception catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
