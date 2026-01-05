import 'draft_post.dart';

/// Перечисление состояний процесса создания поста
enum PostCreationStatus {
  /// Начальное состояние
  initial,

  /// Загрузка данных
  loading,

  /// Готов к публикации
  ready,

  /// Публикация поста
  publishing,

  /// Успешная публикация
  success,

  /// Ошибка
  error,
}

/// Перечисление типов медиа для выбора
enum MediaType {
  /// Изображения
  image,

  /// Видео
  video,

  /// Аудио
  audio,
}

/// Перечисление источников аудио
enum AudioSource {
  /// Избранные треки
  favorites,

  /// Поиск треков
  search,
}

/// Модель состояния создания поста
///
/// Управляет состоянием UI и данными во время создания поста.
class PostCreationState {
  final PostCreationStatus status;
  final DraftPost draftPost;
  final String? errorMessage;
  final bool showFormattingToolbar;
  final MediaType? selectedMediaType;
  final AudioSource audioSource;
  final bool isKeyboardVisible;

  const PostCreationState({
    this.status = PostCreationStatus.initial,
    required this.draftPost,
    this.errorMessage,
    this.showFormattingToolbar = false,
    this.selectedMediaType,
    this.audioSource = AudioSource.favorites,
    this.isKeyboardVisible = false,
  });

  /// Начальное состояние
  factory PostCreationState.initial() {
    return PostCreationState(
      draftPost: DraftPost(
        content: '',
        imagePaths: [],
        audioTrackIds: [],
        savedAt: DateTime.now(),
      ),
    );
  }

  /// Копирование с изменениями
  PostCreationState copyWith({
    PostCreationStatus? status,
    DraftPost? draftPost,
    String? errorMessage,
    bool? showFormattingToolbar,
    MediaType? selectedMediaType,
    AudioSource? audioSource,
    bool? isKeyboardVisible,
  }) {
    return PostCreationState(
      status: status ?? this.status,
      draftPost: draftPost ?? this.draftPost,
      errorMessage: errorMessage,
      showFormattingToolbar: showFormattingToolbar ?? this.showFormattingToolbar,
      selectedMediaType: selectedMediaType ?? this.selectedMediaType,
      audioSource: audioSource ?? this.audioSource,
      isKeyboardVisible: isKeyboardVisible ?? this.isKeyboardVisible,
    );
  }

  /// Проверка, можно ли опубликовать пост
  bool get canPublish => draftPost.isReadyToPublish && status != PostCreationStatus.publishing;

  /// Проверка, есть ли несохраненные изменения
  bool get hasUnsavedChanges =>
      draftPost.content.isNotEmpty ||
      draftPost.imagePaths.isNotEmpty ||
      draftPost.videoPath != null ||
      draftPost.audioTrackIds.isNotEmpty;
}
