import 'package:equatable/equatable.dart';
import 'package:photo_manager/photo_manager.dart';

/// Легковесная модель медиа-ассета для отображения в галерее
///
/// Содержит только необходимые данные для превью и базовой информации,
/// без тяжелых операций вроде получения файла.
class GalleryAsset extends Equatable {
  /// Уникальный идентификатор ассета
  final String id;

  /// Тип медиа-файла
  final AssetType type;

  /// Дата создания файла
  final DateTime createdAt;

  /// Ширина изображения или видео
  final int? width;

  /// Высота изображения или видео
  final int? height;

  /// Длительность видео (только для видео)
  final Duration? duration;

  /// MIME-тип файла
  final String? mimeType;

  const GalleryAsset({
    required this.id,
    required this.type,
    required this.createdAt,
    this.width,
    this.height,
    this.duration,
    this.mimeType,
  });

  /// Создание из AssetEntity
  factory GalleryAsset.fromAssetEntity(AssetEntity asset) {
    return GalleryAsset(
      id: asset.id,
      type: asset.type,
      createdAt: asset.createDateTime,
      width: asset.width,
      height: asset.height,
      duration: asset.videoDuration,
      mimeType: asset.mimeType,
    );
  }

  /// Проверяет, является ли ассет изображением
  bool get isImage => type == AssetType.image;

  /// Проверяет, является ли ассет видео
  bool get isVideo => type == AssetType.video;

  /// Получает соотношение сторон
  double? get aspectRatio {
    if (width != null && height != null && height! > 0) {
      return width! / height!;
    }
    return null;
  }

  /// Получает читаемую длительность видео
  String? get formattedDuration {
    if (duration == null) return null;
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
    id,
    type,
    createdAt,
    width,
    height,
    duration,
    mimeType,
  ];

  @override
  String toString() {
    return 'GalleryAsset(id: $id, type: $type, createdAt: $createdAt)';
  }
}
