/// Модель черновика поста для создания контента
///
/// Хранит временные данные поста во время редактирования.
/// Поддерживает сохранение и восстановление состояния.
class DraftPost {
  final String content;
  final List<String> imagePaths;
  final String? videoPath;
  final List<String> audioTrackIds;
  final DateTime savedAt;
  final bool isDraft;

  DraftPost({
    required this.content,
    required this.imagePaths,
    this.videoPath,
    required this.audioTrackIds,
    required this.savedAt,
    this.isDraft = true,
  });

  /// Создание пустого черновика
  factory DraftPost.empty() {
    return DraftPost(
      content: '',
      imagePaths: [],
      audioTrackIds: [],
      savedAt: DateTime.now(),
    );
  }

  /// Создание из JSON для сохранения/загрузки
  factory DraftPost.fromJson(Map<String, dynamic> json) {
    return DraftPost(
      content: json['content'] as String? ?? '',
      imagePaths: List<String>.from(json['imagePaths'] ?? []),
      videoPath: json['videoPath'] as String?,
      audioTrackIds: List<String>.from(json['audioTrackIds'] ?? []),
      savedAt: DateTime.parse(json['savedAt'] ?? DateTime.now().toIso8601String()),
      isDraft: json['isDraft'] as bool? ?? true,
    );
  }

  /// Преобразование в JSON для сохранения
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'imagePaths': imagePaths,
      'videoPath': videoPath,
      'audioTrackIds': audioTrackIds,
      'savedAt': savedAt.toIso8601String(),
      'isDraft': isDraft,
    };
  }

  /// Копирование с изменениями
  DraftPost copyWith({
    String? content,
    List<String>? imagePaths,
    String? videoPath,
    List<String>? audioTrackIds,
    DateTime? savedAt,
    bool? isDraft,
  }) {
    return DraftPost(
      content: content ?? this.content,
      imagePaths: imagePaths ?? this.imagePaths,
      videoPath: videoPath ?? this.videoPath,
      audioTrackIds: audioTrackIds ?? this.audioTrackIds,
      savedAt: savedAt ?? this.savedAt,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  /// Проверка, пустой ли черновик
  bool get isEmpty =>
      content.isEmpty &&
      imagePaths.isEmpty &&
      videoPath == null &&
      audioTrackIds.isEmpty;

  /// Проверка, готов ли пост к публикации
  /// Пост должен содержать хотя бы текст ИЛИ хотя бы один медиафайл (изображение/видео)
  /// Нельзя создать пост только с музыкой
  bool get isReadyToPublish =>
      content.trim().isNotEmpty || imagePaths.isNotEmpty || videoPath != null;
}
