import 'package:photo_manager/photo_manager.dart';

/// Типы медиа-файлов с устройства
enum LocalMediaType {
  /// Изображение
  image,
  /// Видео
  video,
}

/// Модель медиа-файла с устройства
///
/// Представляет локальный медиа-файл (изображение или видео)
/// с метаданными для отображения в picker.
class LocalMediaItem {
  /// Уникальный идентификатор файла
  final String id;

  /// Путь к файлу в файловой системе (лениво загружается)
  final String? path;

  /// Тип медиа-файла
  final LocalMediaType type;

  /// Дата создания файла
  final DateTime createdAt;

  /// Размер файла в байтах (лениво загружается)
  final int? size;

  /// Ширина изображения или видео (опционально)
  final int? width;

  /// Высота изображения или видео (опционально)
  final int? height;

  /// Длительность видео (только для видео, опционально)
  final Duration? duration;

  /// MIME-тип файла
  final String? mimeType;

  /// AssetEntity для оптимизированного отображения превью
  final AssetEntity? assetEntity;

  const LocalMediaItem({
    required this.id,
    required this.type,
    required this.createdAt,
    this.path,
    this.size,
    this.width,
    this.height,
    this.duration,
    this.mimeType,
    this.assetEntity,
  });

  /// Создание копии с изменениями
  LocalMediaItem copyWith({
    String? id,
    String? path,
    LocalMediaType? type,
    DateTime? createdAt,
    int? size,
    int? width,
    int? height,
    Duration? duration,
    String? mimeType,
    AssetEntity? assetEntity,
  }) {
    return LocalMediaItem(
      id: id ?? this.id,
      path: path ?? this.path,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      size: size ?? this.size,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      mimeType: mimeType ?? this.mimeType,
      assetEntity: assetEntity ?? this.assetEntity,
    );
  }

  /// Проверяет, является ли файл изображением
  bool get isImage => type == LocalMediaType.image;

  /// Проверяет, является ли файл видео
  bool get isVideo => type == LocalMediaType.video;

  /// Получает соотношение сторон
  double? get aspectRatio {
    if (width != null && height != null && height! > 0) {
      return width! / height!;
    }
    return null;
  }

  /// Получает читаемый размер файла
  String get formattedSize {
    if (size == null) return '';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var fileSize = size!.toDouble();
    var i = 0;
    while (fileSize >= 1024 && i < suffixes.length - 1) {
      fileSize /= 1024;
      i++;
    }
    return '${fileSize.toStringAsFixed(1)} ${suffixes[i]}';
  }

  /// Получает читаемую длительность видео
  String? get formattedDuration {
    if (duration == null) return null;
    final minutes = duration!.inMinutes;
    final seconds = duration!.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalMediaItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          path == other.path &&
          type == other.type &&
          createdAt == other.createdAt &&
          size == other.size &&
          width == other.width &&
          height == other.height &&
          duration == other.duration &&
          mimeType == other.mimeType;

  @override
  int get hashCode =>
      Object.hash(id, path, type, createdAt, size, width, height, duration, mimeType);

  @override
  String toString() {
    return 'LocalMediaItem(id: $id, path: $path, type: $type, size: $size, width: $width, height: $height, duration: $duration)';
  }
}
