import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/media_repository.dart';

/// Use case для запроса разрешений на доступ к галерее
class RequestMediaPermissionsUsecase extends UseCase<bool, NoParams> {
  final MediaRepository repository;

  RequestMediaPermissionsUsecase(this.repository);

  @override
  Future<Either<Failure, bool>> call(NoParams params) async {
    final result = await repository.requestPermissions();
    return result;
  }
}
