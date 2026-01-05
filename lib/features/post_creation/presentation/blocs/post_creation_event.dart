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

  const AddVideoEvent(this.videoPath);

  @override
  List<Object?> get props => [videoPath];
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
