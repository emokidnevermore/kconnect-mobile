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
  final bool showPollForm;

  const PostCreationState({
    this.status = PostCreationStatus.initial,
    required this.draftPost,
    this.errorMessage,
    this.showFormattingToolbar = false,
    this.selectedMediaType,
    this.audioSource = AudioSource.favorites,
    this.isKeyboardVisible = false,
    this.showPollForm = false,
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
    bool? showPollForm,
  }) {
    return PostCreationState(
      status: status ?? this.status,
      draftPost: draftPost ?? this.draftPost,
      errorMessage: errorMessage,
      showFormattingToolbar: showFormattingToolbar ?? this.showFormattingToolbar,
      selectedMediaType: selectedMediaType ?? this.selectedMediaType,
      audioSource: audioSource ?? this.audioSource,
      isKeyboardVisible: isKeyboardVisible ?? this.isKeyboardVisible,
      showPollForm: showPollForm ?? this.showPollForm,
    );
  }

  /// Проверка, можно ли опубликовать пост
  bool get canPublish => draftPost.isReadyToPublish && _isPollValid && status != PostCreationStatus.publishing;

  /// Проверка валидности опроса (если он включен)
  bool get _isPollValid {
    if (!showPollForm) return true; // Если форма не показана, то опрос валиден

    final poll = draftPost;
    if (poll.pollQuestion == null || poll.pollQuestion!.trim().isEmpty) return false;
    if (poll.pollOptions.length < 2) return false;

    // Проверяем, что все варианты ответов не пустые
    for (final option in poll.pollOptions) {
      if (option.trim().isEmpty) return false;
    }

    return true;
  }

  /// Проверка, есть ли несохраненные изменения
  bool get hasUnsavedChanges =>
      draftPost.content.isNotEmpty ||
      draftPost.imagePaths.isNotEmpty ||
      draftPost.videoPath != null ||
      draftPost.audioTrackIds.isNotEmpty ||
      draftPost.pollQuestion != null;
}
