import 'package:photo_manager/photo_manager.dart';
import '../../domain/models/local_media_item.dart';

/// Data source для работы с галереей через photo_manager
class PhotoManagerDatasource {
  /// Получает список медиа-файлов из галереи
  Future<List<LocalMediaItem>> getGalleryMedia({
    required int page,
    required int pageSize,
    bool includeVideos = true,
    bool includeImages = true,
  }) async {
    // Определяем типы медиа для запроса
    final requestType = _getRequestType(includeVideos, includeImages);

    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      type: requestType,
      onlyAll: true,
    );

    if (paths.isEmpty) {
      return [];
    }

    final AssetPathEntity recentAlbum = paths.first;

    final List<AssetEntity> assets = await recentAlbum.getAssetListPaged(
      page: page,
      size: pageSize,
    );

    final List<LocalMediaItem> mediaItems = [];
    for (final asset in assets) {
      try {
        final mediaItem = await _convertAssetToMediaItem(asset);
        mediaItems.add(mediaItem);
      } catch (e) {
        continue;
      }
    }

    return mediaItems;
  }

  /// Запрашивает разрешения на доступ к галерее
  Future<bool> requestPermissions() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }

  /// Проверяет, предоставлены ли разрешения
  Future<bool> checkPermissions() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }

  /// Конвертирует AssetEntity в LocalMediaItem
  Future<LocalMediaItem> _convertAssetToMediaItem(AssetEntity asset) async {
    final file = await asset.file;
    final mimeType = asset.mimeType;

    LocalMediaType type;
    if (asset.type == AssetType.image) {
      type = LocalMediaType.image;
    } else if (asset.type == AssetType.video) {
      type = LocalMediaType.video;
    } else {
      // Для других типов используем изображение по умолчанию
      type = LocalMediaType.image;
    }

    int fileSize = 0;
    if (file != null) {
      try {
        fileSize = await file.length();
      } catch (e) {
        // Ошибка получения размера
      }
    }

    return LocalMediaItem(
      id: asset.id,
      path: file?.path ?? '',
      type: type,
      createdAt: asset.createDateTime,
      size: fileSize,
      width: asset.width,
      height: asset.height,
      duration: asset.videoDuration,
      mimeType: mimeType,
    );
  }

  /// Определяет тип запроса на основе параметров
  RequestType _getRequestType(bool includeVideos, bool includeImages) {
    if (includeVideos && includeImages) {
      return RequestType.all;
    } else if (includeVideos) {
      return RequestType.video;
    } else if (includeImages) {
      return RequestType.image;
    } else {
      return RequestType.all;
    }
  }
}
