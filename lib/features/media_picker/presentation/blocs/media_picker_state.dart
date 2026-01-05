import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../domain/models/local_media_item.dart';

/// Состояние MediaPickerBloc
class MediaPickerState extends Equatable {
  /// Список загруженных медиа-файлов
  final List<LocalMediaItem> mediaItems;

  /// Выбранные медиа-файлы
  final Set<String> selectedMediaIds;

  /// Текущая страница пагинации
  final int currentPage;

  /// Размер страницы
  final int pageSize;

  /// Статус загрузки
  final MediaPickerStatus status;

  /// Ошибка, если есть
  final Failure? failure;

  /// Есть ли еще страницы для загрузки
  final bool hasMorePages;

  /// Предоставлены ли разрешения
  final bool hasPermissions;

  const MediaPickerState({
    this.mediaItems = const [],
    this.selectedMediaIds = const {},
    this.currentPage = 0,
    this.pageSize = 50,
    this.status = MediaPickerStatus.initial,
    this.failure,
    this.hasMorePages = true,
    this.hasPermissions = false,
  });

  /// Создание копии состояния с изменениями
  MediaPickerState copyWith({
    List<LocalMediaItem>? mediaItems,
    Set<String>? selectedMediaIds,
    int? currentPage,
    int? pageSize,
    MediaPickerStatus? status,
    Failure? failure,
    bool? hasMorePages,
    bool? hasPermissions,
  }) {
    return MediaPickerState(
      mediaItems: mediaItems ?? this.mediaItems,
      selectedMediaIds: selectedMediaIds ?? this.selectedMediaIds,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      status: status ?? this.status,
      failure: failure ?? this.failure,
      hasMorePages: hasMorePages ?? this.hasMorePages,
      hasPermissions: hasPermissions ?? this.hasPermissions,
    );
  }

  /// Выбранные медиа-файлы
  List<LocalMediaItem> get selectedMediaItems {
    return mediaItems.where((item) => selectedMediaIds.contains(item.id)).toList();
  }

  /// Количество выбранных файлов
  int get selectedCount => selectedMediaIds.length;

  /// Максимальное количество файлов для выбора
  int get maxSelection => 10;

  /// Можно ли выбрать больше файлов
  bool get canSelectMore => selectedCount < maxSelection;

  /// Выбрано ли максимальное количество файлов
  bool get isMaxSelected => selectedCount >= maxSelection;

  /// Можно ли подтвердить выбор
  bool get canConfirm => selectedCount > 0 && status != MediaPickerStatus.loading;

  @override
  List<Object?> get props => [
    mediaItems,
    selectedMediaIds,
    currentPage,
    pageSize,
    status,
    failure,
    hasMorePages,
    hasPermissions,
  ];
}

/// Статусы MediaPickerBloc
enum MediaPickerStatus {
  /// Начальное состояние
  initial,

  /// Загрузка разрешений
  checkingPermissions,

  /// Запрос разрешений
  requestingPermissions,

  /// Загрузка медиа
  loading,

  /// Успешная загрузка
  success,

  /// Ошибка
  error,

  /// Выбор завершен
  confirmed,

  /// Выбор отменен
  cancelled,
}
