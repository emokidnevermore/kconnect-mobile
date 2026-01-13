import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:photo_manager/photo_manager.dart';
import '../../../../core/error/failures.dart';
import '../../domain/models/gallery_album.dart';
import '../../domain/models/local_media_item.dart';
import '../../domain/providers/media_gallery_provider.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/photo_manager_datasource.dart';
import '../providers/ios_gallery_provider.dart';

/// Реализация репозитория для работы с медиа-файлами устройства
class MediaRepositoryImpl implements MediaRepository {
  final PhotoManagerDatasource datasource;
  late final MediaGalleryProvider _provider;

  MediaRepositoryImpl(this.datasource) {
    // Выбираем провайдера в зависимости от платформы
    _provider = Platform.isIOS
        ? IOSGalleryProvider()
        : throw UnimplementedError('Android provider not implemented yet');
  }

  @override
  Future<Either<Failure, List<LocalMediaItem>>> getGalleryMedia({
    required int page,
    required int pageSize,
    bool includeVideos = true,
    bool includeImages = true,
  }) async {
    try {
      // Используем iOS-оптимизированный провайдер
      final assets = await _provider.getAssets(
        page: page,
        pageSize: pageSize,
        includeVideos: includeVideos,
        includeImages: includeImages,
      );

      // Конвертируем AssetEntity в LocalMediaItem для совместимости с UI
      final mediaItems = assets.map((asset) => LocalMediaItem(
        id: asset.id,
        type: asset.type == AssetType.image ? LocalMediaType.image : LocalMediaType.video,
        createdAt: asset.createDateTime,
        width: asset.width,
        height: asset.height,
        duration: asset.videoDuration,
        mimeType: asset.mimeType,
        assetEntity: asset, // Сохраняем AssetEntity для AssetEntityImageProvider
      )).toList();

      return Right(mediaItems);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load gallery media: $e'));
    }
  }

  @override
  Future<Either<Failure, List<GalleryAlbum>>> getGalleryAlbums() async {
    try {
      final albums = await _provider.getAlbums();
      return Right(albums);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load gallery albums: $e'));
    }
  }

  @override
  Future<Either<Failure, List<AssetEntity>>> getAlbumAssets({
    required String albumId,
    required int page,
    required int pageSize,
    bool includeVideos = true,
    bool includeImages = true,
  }) async {
    try {
      final assets = await _provider.getAssets(
        albumId: albumId,
        page: page,
        pageSize: pageSize,
        includeVideos: includeVideos,
        includeImages: includeImages,
      );
      return Right(assets);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load album assets: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> requestPermissions() async {
    try {
      final hasPermission = await _provider.requestPermissions();
      return Right(hasPermission);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to request permissions: $e'));
    }
  }

  @override
  Future<Either<Failure, bool>> checkPermissions() async {
    try {
      final hasPermission = await _provider.checkPermissions();
      return Right(hasPermission);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to check permissions: $e'));
    }
  }
}
