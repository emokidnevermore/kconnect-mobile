import 'package:equatable/equatable.dart';

/// Базовый класс событий для MediaPickerBloc
abstract class MediaPickerEvent extends Equatable {
  const MediaPickerEvent();

  @override
  List<Object?> get props => [];
}

/// Событие загрузки медиа из галереи
class LoadGalleryMediaEvent extends MediaPickerEvent {
  /// Номер страницы для пагинации
  final int page;

  /// Количество элементов на странице
  final int pageSize;

  /// Включать ли видео
  final bool includeVideos;

  /// Включать ли изображения
  final bool includeImages;

  const LoadGalleryMediaEvent({
    this.page = 0,
    this.pageSize = 50,
    this.includeVideos = true,
    this.includeImages = true,
  });

  @override
  List<Object?> get props => [page, pageSize, includeVideos, includeImages];
}

/// Событие выбора медиа-файла
class SelectMediaEvent extends MediaPickerEvent {
  /// Медиа-файл для выбора
  final String mediaId;

  const SelectMediaEvent(this.mediaId);

  @override
  List<Object?> get props => [mediaId];
}

/// Событие отмены выбора медиа-файла
class DeselectMediaEvent extends MediaPickerEvent {
  /// Медиа-файл для отмены выбора
  final String mediaId;

  const DeselectMediaEvent(this.mediaId);

  @override
  List<Object?> get props => [mediaId];
}

/// Событие выбора всех медиа-файлов
class SelectAllMediaEvent extends MediaPickerEvent {
  const SelectAllMediaEvent();
}

/// Событие отмены выбора всех медиа-файлов
class DeselectAllMediaEvent extends MediaPickerEvent {
  const DeselectAllMediaEvent();
}

/// Событие подтверждения выбора медиа-файлов
class ConfirmSelectionEvent extends MediaPickerEvent {
  const ConfirmSelectionEvent();
}

/// Событие отмены выбора и закрытия picker
class CancelSelectionEvent extends MediaPickerEvent {
  const CancelSelectionEvent();
}

/// Событие запроса разрешений
class RequestPermissionsEvent extends MediaPickerEvent {
  const RequestPermissionsEvent();
}

/// Событие сброса состояния
class ResetStateEvent extends MediaPickerEvent {
  const ResetStateEvent();
}
