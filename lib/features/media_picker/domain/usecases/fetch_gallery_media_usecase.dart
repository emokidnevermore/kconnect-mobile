import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../models/local_media_item.dart';
import '../repositories/media_repository.dart';

/// Параметры для получения медиа из галереи
class FetchGalleryMediaParams extends Equatable {
  /// Номер страницы для пагинации (начиная с 0)
  final int page;

  /// Количество элементов на странице
  final int pageSize;

  /// Включать ли видео файлы
  final bool includeVideos;

  /// Включать ли изображения
  final bool includeImages;

  const FetchGalleryMediaParams({
    required this.page,
    required this.pageSize,
    this.includeVideos = true,
    this.includeImages = true,
  });

  @override
  List<Object?> get props => [page, pageSize, includeVideos, includeImages];
}

/// Use case для получения медиа-файлов из галереи устройства
class FetchGalleryMediaUsecase extends UseCase<List<LocalMediaItem>, FetchGalleryMediaParams> {
  final MediaRepository repository;

  FetchGalleryMediaUsecase(this.repository);

  @override
  Future<Either<Failure, List<LocalMediaItem>>> call(FetchGalleryMediaParams params) {
    return repository.getGalleryMedia(
      page: params.page,
      pageSize: params.pageSize,
      includeVideos: params.includeVideos,
      includeImages: params.includeImages,
    );
  }
}
