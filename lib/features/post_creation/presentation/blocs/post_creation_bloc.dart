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

    _startAutoSave();
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
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
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
      savedAt: DateTime.now(),
    );
    emit(state.copyWith(draftPost: updatedDraft));
  }

  /// Обработчик удаления видео
  void _onRemoveVideo(RemoveVideoEvent event, Emitter<PostCreationState> emit) {
    final updatedDraft = state.draftPost.copyWith(
      videoPath: null,
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
        savedAt: DateTime.now(),
      );
      emit(state.copyWith(draftPost: updatedDraft));
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
    if (!state.canPublish) return;

    emit(state.copyWith(status: PostCreationStatus.publishing));

    try {

      final params = CreatePostParams(
        content: state.draftPost.content.trim(),
        isNsfw: false,
        imagePaths: state.draftPost.imagePaths,
        musicTracks: event.selectedTracks,
      );

      final result = await _createPostUsecase.call(params);

      await result.fold(
        (failure) => throw Exception(failure.toString()),
        (post) async {
          emit(state.copyWith(status: PostCreationStatus.success));
        },
      );
    } catch (error) {
      emit(state.copyWith(
        status: PostCreationStatus.error,
        errorMessage: 'Не удалось опубликовать пост: ${error.toString()}',
      ));
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

  /// Запуск авто-сохранения черновика
  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (state.hasUnsavedChanges) {
        add(SaveDraftEvent());
      }
    });
  }
}
