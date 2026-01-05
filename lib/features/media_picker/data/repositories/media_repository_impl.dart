import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/models/local_media_item.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/photo_manager_datasource.dart';

/// Реализация репозитория для работы с медиа-файлами устройства
class MediaRepositoryImpl implements MediaRepository {
  final PhotoManagerDatasource datasource;

  MediaRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, List<LocalMediaItem>>> getGalleryMedia({
    required int page,
    required int pageSize,
    bool includeVideos = true,
    bool includeImages = true,
  }) async {
    try {
      final mediaItems = await datasource.getGalleryMedia(
        page: page,
        pageSize: pageSize,
        includeVideos: includeVideos,
        includeImages: includeImages,
      );
      return Right(mediaItems);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load gallery media: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> requestPermissions() async {
    try {
      final hasPermission = await datasource.requestPermissions();
      return Right(hasPermission);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to request permissions: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> checkPermissions() async {
    try {
      final hasPermission = await datasource.checkPermissions();
      return Right(hasPermission);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to check permissions: $e'));
    }
  }
}
