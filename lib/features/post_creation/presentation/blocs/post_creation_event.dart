import 'package:equatable/equatable.dart';
import '../../../music/domain/models/track.dart';

/// Базовый класс событий для PostCreationBloc
abstract class PostCreationEvent extends Equatable {
  const PostCreationEvent();

  @override
  List<Object?> get props => [];
}

/// Событие обновления текста поста
class UpdateContentEvent extends PostCreationEvent {
  final String content;

  const UpdateContentEvent(this.content);

  @override
  List<Object?> get props => [content];
}

/// Событие добавления изображений
class AddImagesEvent extends PostCreationEvent {
  final List<String> imagePaths;

  const AddImagesEvent(this.imagePaths);

  @override
  List<Object?> get props => [imagePaths];
}

/// Событие удаления изображения
class RemoveImageEvent extends PostCreationEvent {
  final String imagePath;

  const RemoveImageEvent(this.imagePath);

  @override
  List<Object?> get props => [imagePath];
}

/// Событие добавления видео
class AddVideoEvent extends PostCreationEvent {
  final String videoPath;
  final String? videoThumbnailPath;

  const AddVideoEvent(this.videoPath, {this.videoThumbnailPath});

  @override
  List<Object?> get props => [videoPath, videoThumbnailPath];
}

/// Событие удаления видео
class RemoveVideoEvent extends PostCreationEvent {
  const RemoveVideoEvent();

  @override
  List<Object?> get props => [];
}

/// Событие добавления аудио трека
class AddAudioTrackEvent extends PostCreationEvent {
  final String trackId;

  const AddAudioTrackEvent(this.trackId);

  @override
  List<Object?> get props => [trackId];
}

/// Событие удаления аудио трека
class RemoveAudioTrackEvent extends PostCreationEvent {
  final String trackId;

  const RemoveAudioTrackEvent(this.trackId);

  @override
  List<Object?> get props => [trackId];
}



/// Событие переключения панели форматирования
class ToggleFormattingToolbarEvent extends PostCreationEvent {
  const ToggleFormattingToolbarEvent();
}

/// Событие публикации поста
class PublishPostEvent extends PostCreationEvent {
  final List<Track> selectedTracks;

  const PublishPostEvent(this.selectedTracks);

  @override
  List<Object?> get props => [selectedTracks];
}

/// Событие сохранения черновика
class SaveDraftEvent extends PostCreationEvent {
  const SaveDraftEvent();
}

/// Событие загрузки черновика
class LoadDraftEvent extends PostCreationEvent {
  const LoadDraftEvent();
}

/// Событие очистки формы
class ClearFormEvent extends PostCreationEvent {
  const ClearFormEvent();
}

/// Событие сброса состояния при входе в экран
class ResetStateEvent extends PostCreationEvent {
  const ResetStateEvent();
}

/// Событие переключения формы опроса
class TogglePollFormEvent extends PostCreationEvent {
  const TogglePollFormEvent();
}

/// Событие обновления вопроса опроса
class UpdatePollQuestionEvent extends PostCreationEvent {
  final String question;

  const UpdatePollQuestionEvent(this.question);

  @override
  List<Object?> get props => [question];
}

/// Событие добавления варианта ответа
class AddPollOptionEvent extends PostCreationEvent {
  final String option;

  const AddPollOptionEvent(this.option);

  @override
  List<Object?> get props => [option];
}

/// Событие удаления варианта ответа
class RemovePollOptionEvent extends PostCreationEvent {
  final int index;

  const RemovePollOptionEvent(this.index);

  @override
  List<Object?> get props => [index];
}

/// Событие обновления варианта ответа
class UpdatePollOptionEvent extends PostCreationEvent {
  final int index;
  final String option;

  const UpdatePollOptionEvent(this.index, this.option);

  @override
  List<Object?> get props => [index, option];
}

/// Событие переключения анонимности опроса
class TogglePollAnonymousEvent extends PostCreationEvent {
  final bool isAnonymous;

  const TogglePollAnonymousEvent(this.isAnonymous);

  @override
  List<Object?> get props => [isAnonymous];
}

/// Событие переключения множественного выбора
class TogglePollMultipleEvent extends PostCreationEvent {
  final bool isMultiple;

  const TogglePollMultipleEvent(this.isMultiple);

  @override
  List<Object?> get props => [isMultiple];
}

/// Событие обновления срока окончания опроса
class UpdatePollExpiresInDaysEvent extends PostCreationEvent {
  final int? days;

  const UpdatePollExpiresInDaysEvent(this.days);

  @override
  List<Object?> get props => [days];
}
