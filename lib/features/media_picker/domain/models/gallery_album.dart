import 'package:equatable/equatable.dart';
import 'package:photo_manager/photo_manager.dart';

/// Модель альбома галереи
class GalleryAlbum extends Equatable {
  /// Уникальный идентификатор альбома
  final String id;

  /// Название альбома
  final String name;

  /// Количество ассетов в альбоме
  final int assetCount;

  /// Является ли альбом виртуальным (например, "Все фото", "Все видео")
  final bool isVirtual;

  const GalleryAlbum({
    required this.id,
    required this.name,
    required this.assetCount,
    this.isVirtual = false,
  });

  /// Создание из AssetPathEntity (асинхронно, для получения assetCount)
  static Future<GalleryAlbum> fromAssetPathAsync(AssetPathEntity path) async {
    final assetCount = await path.assetCountAsync;
    return GalleryAlbum(
      id: path.id,
      name: path.name,
      assetCount: assetCount,
      isVirtual: false,
    );
  }

  /// Создание из AssetPathEntity (синхронно, assetCount нужно передать отдельно)
  factory GalleryAlbum.fromAssetPath(AssetPathEntity path, int assetCount) {
    return GalleryAlbum(
      id: path.id,
      name: path.name,
      assetCount: assetCount,
      isVirtual: false,
    );
  }

  /// Виртуальный альбом "Все фото"
  factory GalleryAlbum.virtualPhotos() {
    return const GalleryAlbum(
      id: 'virtual_photos',
      name: 'Фото',
      assetCount: 0, // Будет установлено динамически
      isVirtual: true,
    );
  }

  /// Виртуальный альбом "Все видео"
  factory GalleryAlbum.virtualVideos() {
    return const GalleryAlbum(
      id: 'virtual_videos',
      name: 'Видео',
      assetCount: 0, // Будет установлено динамически
      isVirtual: true,
    );
  }

  /// Создание копии с обновленным количеством ассетов
  GalleryAlbum copyWithAssetCount(int assetCount) {
    return GalleryAlbum(
      id: id,
      name: name,
      assetCount: assetCount,
      isVirtual: isVirtual,
    );
  }

  @override
  List<Object?> get props => [id, name, assetCount, isVirtual];

  @override
  String toString() {
    return 'GalleryAlbum(id: $id, name: $name, assetCount: $assetCount, isVirtual: $isVirtual)';
  }
}
