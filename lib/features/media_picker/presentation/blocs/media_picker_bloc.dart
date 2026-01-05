import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/usecases/fetch_gallery_media_usecase.dart';
import '../../domain/usecases/request_media_permissions_usecase.dart';
import 'media_picker_event.dart';
import 'media_picker_state.dart';

/// BLoC для управления состоянием MediaPicker
class MediaPickerBloc extends Bloc<MediaPickerEvent, MediaPickerState> {
  final FetchGalleryMediaUsecase fetchGalleryMediaUsecase;
  final RequestMediaPermissionsUsecase requestPermissionsUsecase;

  MediaPickerBloc({
    required this.fetchGalleryMediaUsecase,
    required this.requestPermissionsUsecase,
  }) : super(const MediaPickerState()) {
    on<LoadGalleryMediaEvent>(_onLoadGalleryMedia);
    on<SelectMediaEvent>(_onSelectMedia);
    on<DeselectMediaEvent>(_onDeselectMedia);
    on<SelectAllMediaEvent>(_onSelectAllMedia);
    on<DeselectAllMediaEvent>(_onDeselectAllMedia);
    on<ConfirmSelectionEvent>(_onConfirmSelection);
    on<CancelSelectionEvent>(_onCancelSelection);
    on<RequestPermissionsEvent>(_onRequestPermissions);
    on<ResetStateEvent>(_onResetState);
  }

  /// Обработка загрузки медиа из галереи
  Future<void> _onLoadGalleryMedia(
    LoadGalleryMediaEvent event,
    Emitter<MediaPickerState> emit,
  ) async {
    // Проверяем разрешения перед загрузкой
    if (!state.hasPermissions) {
      emit(state.copyWith(status: MediaPickerStatus.checkingPermissions));
      final permissionResult = await requestPermissionsUsecase(NoParams());
      permissionResult.fold(
        (failure) {
          emit(state.copyWith(
            status: MediaPickerStatus.error,
            failure: failure,
          ));
          return;
        },
        (hasPermission) {
          emit(state.copyWith(hasPermissions: hasPermission));
          if (!hasPermission) {
            emit(state.copyWith(status: MediaPickerStatus.error));
            return;
          }
        },
      );
    }

    emit(state.copyWith(status: MediaPickerStatus.loading));

    final params = FetchGalleryMediaParams(
      page: event.page,
      pageSize: event.pageSize,
      includeVideos: event.includeVideos,
      includeImages: event.includeImages,
    );

    final result = await fetchGalleryMediaUsecase(params);

    result.fold(
      (failure) {
        emit(state.copyWith(
          status: MediaPickerStatus.error,
          failure: failure,
        ));
      },
      (mediaItems) {
        final isFirstPage = event.page == 0;
        final updatedMediaItems = isFirstPage
            ? mediaItems
            : [...state.mediaItems, ...mediaItems];

        final hasMorePages = mediaItems.length >= event.pageSize;

        emit(state.copyWith(
          mediaItems: updatedMediaItems,
          currentPage: event.page,
          pageSize: event.pageSize,
          status: MediaPickerStatus.success,
          hasMorePages: hasMorePages,
        ));
      },
    );
  }

  /// Обработка выбора медиа-файла
  void _onSelectMedia(
    SelectMediaEvent event,
    Emitter<MediaPickerState> emit,
  ) {
    if (!state.canSelectMore) return;

    final updatedSelectedIds = Set<String>.from(state.selectedMediaIds)
      ..add(event.mediaId);

    emit(state.copyWith(selectedMediaIds: updatedSelectedIds));
  }

  /// Обработка отмены выбора медиа-файла
  void _onDeselectMedia(
    DeselectMediaEvent event,
    Emitter<MediaPickerState> emit,
  ) {
    final updatedSelectedIds = Set<String>.from(state.selectedMediaIds)
      ..remove(event.mediaId);

    emit(state.copyWith(selectedMediaIds: updatedSelectedIds));
  }

  /// Обработка выбора всех медиа-файлов
  void _onSelectAllMedia(
    SelectAllMediaEvent event,
    Emitter<MediaPickerState> emit,
  ) {
    final maxSelectable = state.mediaItems.take(state.maxSelection);
    final selectedIds = maxSelectable.map((item) => item.id).toSet();

    emit(state.copyWith(selectedMediaIds: selectedIds));
  }

  /// Обработка отмены выбора всех медиа-файлов
  void _onDeselectAllMedia(
    DeselectAllMediaEvent event,
    Emitter<MediaPickerState> emit,
  ) {
    emit(state.copyWith(selectedMediaIds: const {}));
  }

  /// Обработка подтверждения выбора
  void _onConfirmSelection(
    ConfirmSelectionEvent event,
    Emitter<MediaPickerState> emit,
  ) {
    emit(state.copyWith(status: MediaPickerStatus.confirmed));
  }

  /// Обработка отмены выбора
  void _onCancelSelection(
    CancelSelectionEvent event,
    Emitter<MediaPickerState> emit,
  ) {
    emit(state.copyWith(status: MediaPickerStatus.cancelled));
  }

  /// Обработка запроса разрешений
  Future<void> _onRequestPermissions(
    RequestPermissionsEvent event,
    Emitter<MediaPickerState> emit,
  ) async {
    emit(state.copyWith(status: MediaPickerStatus.requestingPermissions));

    final result = await requestPermissionsUsecase(NoParams());

    result.fold(
      (failure) {
        emit(state.copyWith(
          status: MediaPickerStatus.error,
          failure: failure,
        ));
      },
      (hasPermission) {
        emit(state.copyWith(
          hasPermissions: hasPermission,
          status: hasPermission ? MediaPickerStatus.success : MediaPickerStatus.error,
        ));
      },
    );
  }

  /// Обработка сброса состояния
  void _onResetState(
    ResetStateEvent event,
    Emitter<MediaPickerState> emit,
  ) {
    emit(const MediaPickerState());
  }
}
