import 'package:photo_manager/photo_manager.dart';
import '../models/gallery_album.dart';

/// Абстрактный провайдер для работы с галереей устройства
///
/// Обеспечивает платформенную абстракцию для получения медиа-ассетов
/// и альбомов с учетом особенностей iOS и Android.
abstract class MediaGalleryProvider {
  /// Получает список ассетов из галереи
  ///
  /// [page] - номер страницы для пагинации (начиная с 0)
  /// [pageSize] - количество элементов на странице
  /// [includeVideos] - включать ли видео
  /// [includeImages] - включать ли изображения
  /// [albumId] - ID альбома для фильтрации (null для всех ассетов)
  Future<List<AssetEntity>> getAssets({
    required int page,
    required int pageSize,
    bool includeVideos = true,
    bool includeImages = true,
    String? albumId,
  });

  /// Получает список альбомов галереи
  Future<List<GalleryAlbum>> getAlbums();

  /// Запрашивает разрешения на доступ к галерее
  Future<bool> requestPermissions();

  /// Проверяет, предоставлены ли разрешения
  Future<bool> checkPermissions();
}
