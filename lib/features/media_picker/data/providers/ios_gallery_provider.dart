import 'package:photo_manager/photo_manager.dart';
import '../../domain/models/gallery_album.dart';
import '../../domain/providers/media_gallery_provider.dart';

/// iOS-специфичная реализация провайдера галереи
///
/// Учитывает особенности iOS PhotoKit:
/// - Фильтрует системные альбомы (Hidden, Recently Deleted)
/// - Ручная сортировка ассетов по createDateTime DESC
/// - Правильная обработка виртуальных альбомов "Все фото"/"Все видео"
/// - Учет iCloud-ассетов
class IOSGalleryProvider implements MediaGalleryProvider {
  AssetPathEntity? _allPhotosAlbum;
  AssetPathEntity? _allVideosAlbum;

  @override
  Future<List<AssetEntity>> getAssets({
    required int page,
    required int pageSize,
    bool includeVideos = true,
    bool includeImages = true,
    String? albumId,
  }) async {
    // Определяем тип запроса
    final requestType = _getRequestType(includeVideos, includeImages);

    // Получаем подходящий альбом
    final album = await _getAlbumForRequest(requestType, albumId);
    if (album == null) return [];

    // Получаем ассеты из альбома
    final assets = await album.getAssetListPaged(
      page: page,
      size: pageSize,
    );

    // Фильтруем WebP файлы (iOS специфично)
    final filteredAssets = assets.where((asset) {
      final fileName = asset.title?.toLowerCase() ?? '';
      return !fileName.endsWith('.webp');
    }).toList();

    // Ручная сортировка по дате создания (новые сверху)
    // iOS PhotoKit может возвращать ассеты не в правильном порядке
    filteredAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

    return filteredAssets;
  }

  @override
  Future<List<GalleryAlbum>> getAlbums() async {
    final albums = <GalleryAlbum>[];

    // Получаем все альбомы без виртуальных
    final imagePaths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: false,
    );
    final videoPaths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      hasAll: false,
    );

    // Объединяем и удаляем дубликаты
    final allPaths = <AssetPathEntity>{...imagePaths, ...videoPaths};

    // Создаем альбомы с асинхронным получением assetCount
    final albumFutures = allPaths.map((path) => GalleryAlbum.fromAssetPathAsync(path));
    final allAlbums = await Future.wait(albumFutures);

    // Фильтруем системные и пустые альбомы
    final filteredAlbums = allAlbums.where(_isValidAlbum).toList();

    // Сортируем по количеству ассетов (большие альбомы сверху)
    filteredAlbums.sort((a, b) => b.assetCount.compareTo(a.assetCount));

    // Добавляем виртуальные альбомы в начало
    final virtualAlbums = await _createVirtualAlbums();
    albums.addAll(virtualAlbums);
    albums.addAll(filteredAlbums);

    return albums;
  }

  @override
  Future<bool> requestPermissions() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }

  @override
  Future<bool> checkPermissions() async {
    final ps = await PhotoManager.requestPermissionExtend();
    return ps.isAuth;
  }

  /// Получает подходящий альбом для запроса
  Future<AssetPathEntity?> _getAlbumForRequest(RequestType requestType, String? albumId) async {
    // Если указан конкретный альбом
    if (albumId != null) {
      if (albumId == 'virtual_photos') {
        return _getAllPhotosAlbum();
      } else if (albumId == 'virtual_videos') {
        return _getAllVideosAlbum();
      } else {
        // Ищем альбом по ID среди всех альбомов
        final allPaths = await PhotoManager.getAssetPathList(type: requestType);
        return allPaths.cast<AssetPathEntity?>().firstWhere(
          (path) => path?.id == albumId,
          orElse: () => null,
        );
      }
    }

    // Для общего запроса используем "Все фото" или fallback
    return _getAllPhotosAlbum();
  }

  /// Получает альбом "Все фото"
  Future<AssetPathEntity?> _getAllPhotosAlbum() async {
    if (_allPhotosAlbum != null) return _allPhotosAlbum;

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
    );

    if (paths.isNotEmpty) {
      _allPhotosAlbum = paths.first;
    }

    return _allPhotosAlbum;
  }

  /// Получает альбом "Все видео"
  Future<AssetPathEntity?> _getAllVideosAlbum() async {
    if (_allVideosAlbum != null) return _allVideosAlbum;

    final paths = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      onlyAll: true,
    );

    if (paths.isNotEmpty) {
      _allVideosAlbum = paths.first;
    }

    return _allVideosAlbum;
  }

  /// Создает виртуальные альбомы "Все фото" и "Все видео"
  Future<List<GalleryAlbum>> _createVirtualAlbums() async {
    final virtualAlbums = <GalleryAlbum>[];

    // Виртуальный альбом "Все фото"
    final photosAlbum = await _getAllPhotosAlbum();
    if (photosAlbum != null) {
      final photoCount = await photosAlbum.assetCountAsync;
      virtualAlbums.add(GalleryAlbum.virtualPhotos().copyWithAssetCount(photoCount));
    }

    // Виртуальный альбом "Все видео"
    final videosAlbum = await _getAllVideosAlbum();
    if (videosAlbum != null) {
      final videoCount = await videosAlbum.assetCountAsync;
      virtualAlbums.add(GalleryAlbum.virtualVideos().copyWithAssetCount(videoCount));
    }

    return virtualAlbums;
  }

  /// Проверяет, является ли альбом валидным для отображения
  bool _isValidAlbum(GalleryAlbum album) {
    // Исключаем пустые альбомы
    if (album.assetCount == 0) return false;

    // Исключаем системные альбомы
    final name = album.name.toLowerCase();
    if (name == 'hidden' || name == 'recently deleted') return false;
    if (name.startsWith('.')) return false; // Скрытые альбомы

    return true;
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
