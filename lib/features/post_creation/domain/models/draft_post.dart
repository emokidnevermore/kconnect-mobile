/// Модель черновика поста для создания контента
///
/// Хранит временные данные поста во время редактирования.
/// Поддерживает сохранение и восстановление состояния.
class DraftPost {
  final String content;
  final List<String> imagePaths;
  final String? videoPath;
  final String? videoThumbnailPath;
  final List<String> audioTrackIds;
  final DateTime savedAt;
  final bool isDraft;
  final String? pollQuestion;
  final List<String> pollOptions;
  final bool pollIsAnonymous;
  final bool pollIsMultiple;
  final int? pollExpiresInDays;

  DraftPost({
    required this.content,
    required this.imagePaths,
    this.videoPath,
    this.videoThumbnailPath,
    required this.audioTrackIds,
    required this.savedAt,
    this.isDraft = true,
    this.pollQuestion,
    this.pollOptions = const [],
    this.pollIsAnonymous = false,
    this.pollIsMultiple = false,
    this.pollExpiresInDays,
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
      videoThumbnailPath: json['videoThumbnailPath'] as String?,
      audioTrackIds: List<String>.from(json['audioTrackIds'] ?? []),
      savedAt: DateTime.parse(json['savedAt'] ?? DateTime.now().toIso8601String()),
      isDraft: json['isDraft'] as bool? ?? true,
      pollQuestion: json['pollQuestion'] as String?,
      pollOptions: List<String>.from(json['pollOptions'] ?? []),
      pollIsAnonymous: json['pollIsAnonymous'] as bool? ?? false,
      pollIsMultiple: json['pollIsMultiple'] as bool? ?? false,
      pollExpiresInDays: json['pollExpiresInDays'] as int?,
    );
  }

  /// Преобразование в JSON для сохранения
  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'imagePaths': imagePaths,
      'videoPath': videoPath,
      'videoThumbnailPath': videoThumbnailPath,
      'audioTrackIds': audioTrackIds,
      'savedAt': savedAt.toIso8601String(),
      'isDraft': isDraft,
      'pollQuestion': pollQuestion,
      'pollOptions': pollOptions,
      'pollIsAnonymous': pollIsAnonymous,
      'pollIsMultiple': pollIsMultiple,
      'pollExpiresInDays': pollExpiresInDays,
    };
  }

  /// Копирование с изменениями
  DraftPost copyWith({
    String? content,
    List<String>? imagePaths,
    String? videoPath,
    String? videoThumbnailPath,
    List<String>? audioTrackIds,
    DateTime? savedAt,
    bool? isDraft,
    String? pollQuestion,
    List<String>? pollOptions,
    bool? pollIsAnonymous,
    bool? pollIsMultiple,
    int? pollExpiresInDays,
  }) {
    return DraftPost(
      content: content ?? this.content,
      imagePaths: imagePaths ?? this.imagePaths,
      videoPath: videoPath ?? this.videoPath,
      videoThumbnailPath: videoThumbnailPath ?? this.videoThumbnailPath,
      audioTrackIds: audioTrackIds ?? this.audioTrackIds,
      savedAt: savedAt ?? this.savedAt,
      isDraft: isDraft ?? this.isDraft,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      pollOptions: pollOptions ?? this.pollOptions,
      pollIsAnonymous: pollIsAnonymous ?? this.pollIsAnonymous,
      pollIsMultiple: pollIsMultiple ?? this.pollIsMultiple,
      pollExpiresInDays: pollExpiresInDays ?? this.pollExpiresInDays,
    );
  }

  /// Проверка, пустой ли черновик
  bool get isEmpty =>
      content.isEmpty &&
      imagePaths.isEmpty &&
      videoPath == null &&
      audioTrackIds.isEmpty &&
      pollQuestion == null;

  /// Проверка, готов ли пост к публикации
  /// Пост должен содержать хотя бы текст ИЛИ медиа ИЛИ опрос
  /// Нельзя создать пост только с музыкой
  bool get isReadyToPublish =>
      content.trim().isNotEmpty ||
      imagePaths.isNotEmpty ||
      videoPath != null ||
      (pollQuestion?.isNotEmpty == true && pollOptions.length >= 2);
}
