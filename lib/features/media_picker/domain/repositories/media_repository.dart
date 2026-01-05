import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../models/local_media_item.dart';

/// Абстрактный репозиторий для работы с медиа-файлами устройства
abstract class MediaRepository {
  /// Получает список медиа-файлов из галереи устройства
  ///
  /// [page] - номер страницы для пагинации (начиная с 0)
  /// [pageSize] - количество элементов на странице
  /// [includeVideos] - включать ли видео файлы
  /// [includeImages] - включать ли изображения
  Future<Either<Failure, List<LocalMediaItem>>> getGalleryMedia({
    required int page,
    required int pageSize,
    bool includeVideos = true,
    bool includeImages = true,
  });

  /// Запрашивает разрешения на доступ к галерее
  Future<Either<Failure, bool>> requestPermissions();

  /// Проверяет, предоставлены ли разрешения на доступ к галерее
  Future<Either<Failure, bool>> checkPermissions();
}
