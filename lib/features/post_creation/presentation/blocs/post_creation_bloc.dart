import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/models/draft_post.dart';
import '../../domain/models/post_creation_state.dart';
import '../../domain/usecases/create_post_usecase.dart';
import '../../domain/models/create_post_params.dart';
import 'post_creation_event.dart';

/// BLoC для управления состоянием создания поста
///
/// Обрабатывает события создания поста, управляет черновиками,
/// валидирует данные и координирует публикацию.
class PostCreationBloc extends Bloc<PostCreationEvent, PostCreationState> {
  /// UseCase для создания поста
  final CreatePostUsecase _createPostUsecase;

  /// Таймер для авто-сохранения черновика
  Timer? _autoSaveTimer;

  /// Флаг предотвращения множественных публикаций
  bool _isPublishingInProgress = false;

  PostCreationBloc(this._createPostUsecase) : super(PostCreationState.initial()) {
    on<UpdateContentEvent>(_onUpdateContent);
    on<AddImagesEvent>(_onAddImages);
    on<RemoveImageEvent>(_onRemoveImage);
    on<AddVideoEvent>(_onAddVideo);
    on<RemoveVideoEvent>(_onRemoveVideo);
    on<AddAudioTrackEvent>(_onAddAudioTrack);
    on<RemoveAudioTrackEvent>(_onRemoveAudioTrack);

    on<ToggleFormattingToolbarEvent>(_onToggleFormattingToolbar);
    on<PublishPostEvent>(_onPublishPost);
    on<SaveDraftEvent>(_onSaveDraft);
    on<LoadDraftEvent>(_onLoadDraft);
    on<ClearFormEvent>(_onClearForm);
    on<ResetStateEvent>(_onResetState);

    // Poll events
    on<TogglePollFormEvent>(_onTogglePollForm);
    on<UpdatePollQuestionEvent>(_onUpdatePollQuestion);
    on<AddPollOptionEvent>(_onAddPollOption);
    on<RemovePollOptionEvent>(_onRemovePollOption);
    on<UpdatePollOptionEvent>(_onUpdatePollOption);
    on<TogglePollAnonymousEvent>(_onTogglePollAnonymous);
    on<TogglePollMultipleEvent>(_onTogglePollMultiple);
    on<UpdatePollExpiresInDaysEvent>(_onUpdatePollExpiresInDays);

    // Отключаем авто-сохранение для предотвращения сохранения состояния опросов
    // _startAutoSave();
  }

  @override
  Future<void> close() {
    _autoSaveTimer?.cancel();
    return super.close();
  }

  /// Обработчик обновления текста
  void _onUpdateContent(UpdateContentEvent event, Emitter<PostCreationState> emit) {
    final updatedDraft = state.draftPost.copyWith(
      content: event.content,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик добавления изображений
  void _onAddImages(AddImagesEvent event, Emitter<PostCreationState> emit) {
    final currentImages = List<String>.from(state.draftPost.imagePaths);
    final newImages = event.imagePaths.take(10 - currentImages.length);
    currentImages.addAll(newImages);

    final updatedDraft = state.draftPost.copyWith(
      imagePaths: currentImages,
      // Автоматически отключаем опрос при добавлении медиа
      pollQuestion: null,
      pollOptions: [],
      pollIsAnonymous: false,
      pollIsMultiple: false,
      pollExpiresInDays: null,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(
      draftPost: updatedDraft,
      showPollForm: false, // Скрываем форму опроса
    ));
  }

  /// Обработчик удаления изображения
  void _onRemoveImage(RemoveImageEvent event, Emitter<PostCreationState> emit) {
    final currentImages = List<String>.from(state.draftPost.imagePaths);
    currentImages.remove(event.imagePath);

    final updatedDraft = state.draftPost.copyWith(
      imagePaths: currentImages,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик добавления видео
  void _onAddVideo(AddVideoEvent event, Emitter<PostCreationState> emit) {
    final updatedDraft = state.draftPost.copyWith(
      videoPath: event.videoPath,
      videoThumbnailPath: event.videoThumbnailPath,
      // Автоматически отключаем опрос при добавлении медиа
      pollQuestion: null,
      pollOptions: [],
      pollIsAnonymous: false,
      pollIsMultiple: false,
      pollExpiresInDays: null,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(
      draftPost: updatedDraft,
      showPollForm: false, // Скрываем форму опроса
    ));
  }

  /// Обработчик удаления видео
  void _onRemoveVideo(RemoveVideoEvent event, Emitter<PostCreationState> emit) {
    final updatedDraft = state.draftPost.copyWith(
      videoPath: null,
      videoThumbnailPath: null,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик добавления аудио трека
  void _onAddAudioTrack(AddAudioTrackEvent event, Emitter<PostCreationState> emit) {
    final currentTracks = List<String>.from(state.draftPost.audioTrackIds);
    if (!currentTracks.contains(event.trackId) && currentTracks.length < 5) {
      currentTracks.add(event.trackId);

      final updatedDraft = state.draftPost.copyWith(
        audioTrackIds: currentTracks,
        // Автоматически отключаем опрос при добавлении медиа
        pollQuestion: null,
        pollOptions: [],
        pollIsAnonymous: false,
        pollIsMultiple: false,
        pollExpiresInDays: null,
        savedAt: DateTime.now(),
      );
      emit(state.copyWith(
        draftPost: updatedDraft,
        showPollForm: false, // Скрываем форму опроса
      ));
    }
  }

  /// Обработчик удаления аудио трека
  void _onRemoveAudioTrack(RemoveAudioTrackEvent event, Emitter<PostCreationState> emit) {
    final currentTracks = List<String>.from(state.draftPost.audioTrackIds);
    currentTracks.remove(event.trackId);

    final updatedDraft = state.draftPost.copyWith(
      audioTrackIds: currentTracks,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }



  /// Обработчик переключения панели форматирования
  void _onToggleFormattingToolbar(ToggleFormattingToolbarEvent event, Emitter<PostCreationState> emit) {
    emit(state.copyWith(showFormattingToolbar: !state.showFormattingToolbar));
  }

  /// Обработчик публикации поста
  void _onPublishPost(PublishPostEvent event, Emitter<PostCreationState> emit) async {

    // Проверяем все условия блокировки
    if (_isPublishingInProgress) {
      return;
    }

    if (state.status == PostCreationStatus.publishing) {
      return;
    }

    if (!state.canPublish) {
      return;
    }

    // Устанавливаем флаг блокировки ДО начала операции
    _isPublishingInProgress = true;
    emit(state.copyWith(status: PostCreationStatus.publishing));

    try {
      final params = CreatePostParams(
        content: state.draftPost.content.trim(),
        isNsfw: false,
        imagePaths: state.draftPost.imagePaths,
        videoPath: state.draftPost.videoPath,
        videoThumbnailPath: state.draftPost.videoThumbnailPath,
        musicTracks: event.selectedTracks,
        pollQuestion: state.draftPost.pollQuestion,
        pollOptions: state.draftPost.pollOptions,
        pollIsAnonymous: state.draftPost.pollIsAnonymous,
        pollIsMultiple: state.draftPost.pollIsMultiple,
        pollExpiresInDays: state.draftPost.pollExpiresInDays,
      );

      final result = await _createPostUsecase.call(params);

      await result.fold(
        (failure) {
          throw Exception(failure.toString());
        },
        (post) {
          emit(state.copyWith(status: PostCreationStatus.success));
        },
      );
    } catch (error) {
      emit(state.copyWith(
        status: PostCreationStatus.error,
        errorMessage: 'Не удалось опубликовать пост: ${error.toString()}',
      ));
    } finally {
      // Сбрасываем флаг ТОЛЬКО в finally блоке
      _isPublishingInProgress = false;
    }
  }




  /// Обработчик сохранения черновика
  void _onSaveDraft(SaveDraftEvent event, Emitter<PostCreationState> emit) {
    // TODO: Реализовать сохранение в локальное хранилище
    final updatedDraft = state.draftPost.copyWith(
      isDraft: true,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик загрузки черновика
  void _onLoadDraft(LoadDraftEvent event, Emitter<PostCreationState> emit) {
    // TODO: Реализовать загрузку из локального хранилища
    // Пока просто создаем пустой черновик
    emit(state.copyWith(draftPost: DraftPost.empty()));
  }

  /// Обработчик очистки формы
  void _onClearForm(ClearFormEvent event, Emitter<PostCreationState> emit) {
    emit(PostCreationState.initial());
  }

  /// Обработчик сброса состояния при входе в экран
  void _onResetState(ResetStateEvent event, Emitter<PostCreationState> emit) {
    _isPublishingInProgress = false;
    emit(PostCreationState.initial());
  }

  /// Обработчик переключения формы опроса
  void _onTogglePollForm(TogglePollFormEvent event, Emitter<PostCreationState> emit) {
    if (state.showPollForm) {
      // Скрываем форму и очищаем данные опроса
      final updatedDraft = state.draftPost.copyWith(
        pollQuestion: null,
        pollOptions: [],
        pollIsAnonymous: false,
        pollIsMultiple: false,
        pollExpiresInDays: null,
        savedAt: DateTime.now(),
      );
      emit(state.copyWith(
        draftPost: updatedDraft,
        showPollForm: false,
      ));
    } else {
      // Показываем форму и автоматически удаляем все медиа-контент
      // (опросы не могут сочетаться с картинками, видео или музыкой)
      final updatedDraft = state.draftPost.copyWith(
        imagePaths: [], // Удаляем все картинки
        videoPath: null, // Удаляем видео
        videoThumbnailPath: null,
        audioTrackIds: [], // Удаляем музыку
        savedAt: DateTime.now(),
      );
      emit(state.copyWith(
        draftPost: updatedDraft,
        showPollForm: true,
      ));
    }
  }

  /// Обработчик обновления вопроса опроса
  void _onUpdatePollQuestion(UpdatePollQuestionEvent event, Emitter<PostCreationState> emit) {
    final updatedDraft = state.draftPost.copyWith(
      pollQuestion: event.question.isEmpty ? null : event.question,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик добавления варианта ответа
  void _onAddPollOption(AddPollOptionEvent event, Emitter<PostCreationState> emit) {
    if (state.draftPost.pollOptions.length >= 10) return;

    final currentOptions = List<String>.from(state.draftPost.pollOptions);
    currentOptions.add(event.option);

    final updatedDraft = state.draftPost.copyWith(
      pollOptions: currentOptions,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик удаления варианта ответа
  void _onRemovePollOption(RemovePollOptionEvent event, Emitter<PostCreationState> emit) {
    if (state.draftPost.pollOptions.length <= 2) return;

    final currentOptions = List<String>.from(state.draftPost.pollOptions);
    if (event.index >= 0 && event.index < currentOptions.length) {
      currentOptions.removeAt(event.index);
    }

    final updatedDraft = state.draftPost.copyWith(
      pollOptions: currentOptions,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик обновления варианта ответа
  void _onUpdatePollOption(UpdatePollOptionEvent event, Emitter<PostCreationState> emit) {
    final currentOptions = List<String>.from(state.draftPost.pollOptions);
    if (event.index >= 0 && event.index < currentOptions.length) {
      currentOptions[event.index] = event.option;
    }

    final updatedDraft = state.draftPost.copyWith(
      pollOptions: currentOptions,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик переключения анонимности опроса
  void _onTogglePollAnonymous(TogglePollAnonymousEvent event, Emitter<PostCreationState> emit) {
    final updatedDraft = state.draftPost.copyWith(
      pollIsAnonymous: event.isAnonymous,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик переключения множественного выбора
  void _onTogglePollMultiple(TogglePollMultipleEvent event, Emitter<PostCreationState> emit) {
    final updatedDraft = state.draftPost.copyWith(
      pollIsMultiple: event.isMultiple,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик обновления срока окончания опроса
  void _onUpdatePollExpiresInDays(UpdatePollExpiresInDaysEvent event, Emitter<PostCreationState> emit) {
    final updatedDraft = state.draftPost.copyWith(
      pollExpiresInDays: event.days,
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

}
