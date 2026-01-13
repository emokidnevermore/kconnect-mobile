import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../core/utils/theme_extensions.dart';
import '../blocs/media_picker_bloc.dart';
import '../blocs/media_picker_event.dart';
import '../blocs/media_picker_state.dart';

/// Виджет сетки галереи для выбора медиа-файлов
///
/// Отображает медиа-файлы в виде сетки с возможностью прокрутки,
/// пагинацией и выбором нескольких элементов.
class GalleryGridView extends StatefulWidget {
  /// Максимальное количество выбираемых файлов
  final int maxSelection;

  const GalleryGridView({
    super.key,
    this.maxSelection = 10,
  });

  @override
  State<GalleryGridView> createState() => _GalleryGridViewState();
}

class _GalleryGridViewState extends State<GalleryGridView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Обработка прокрутки для пагинации
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final threshold = maxScroll * 0.8;
    if (currentScroll >= threshold) {
      final state = context.read<MediaPickerBloc>().state;
      if (state.hasMorePages && state.status != MediaPickerStatus.loading) {
        context.read<MediaPickerBloc>().add(
          LoadGalleryMediaEvent(
            page: state.currentPage + 1,
            pageSize: state.pageSize,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MediaPickerBloc, MediaPickerState>(
      builder: (context, state) {
        if (state.mediaItems.isEmpty && state.status == MediaPickerStatus.success) {
          return _buildEmptyState();
        }

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: state.mediaItems.length + (state.hasMorePages ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == state.mediaItems.length) {
              return _buildLoadingIndicator();
            }

            final mediaItem = state.mediaItems[index];
            final isSelected = state.selectedMediaIds.contains(mediaItem.id);

            return GestureDetector(
              onTap: () {
                if (isSelected) {
                  context.read<MediaPickerBloc>().add(
                    DeselectMediaEvent(mediaItem.id),
                  );
                } else if (state.canSelectMore) {
                  context.read<MediaPickerBloc>().add(
                    SelectMediaEvent(mediaItem.id),
                  );
                }
              },
              child: Stack(
                children: [
                  // Превью изображения/видео
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? context.dynamicPrimaryColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: mediaItem.assetEntity != null
                            ? AssetEntityImage(
                                mediaItem.assetEntity!,
                                fit: BoxFit.cover,
                                width: 200,
                                height: 200,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Theme.of(context).colorScheme.surface,
                                    child: const Icon(Icons.warning, color: Colors.white),
                                  );
                                },
                              )
                            : mediaItem.path != null
                                ? Image.file(
                                    File(mediaItem.path!),
                                    fit: BoxFit.cover,
                                    cacheWidth: 200,
                                    cacheHeight: 200,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Theme.of(context).colorScheme.surface,
                                        child: const Icon(Icons.warning, color: Colors.white),
                                      );
                                    },
                                  )
                                : Container(
                                    color: Theme.of(context).colorScheme.surface,
                                    child: const Icon(Icons.image, color: Colors.white),
                                  ),
                      ),
                    ),
                  ),

                  // Индикатор выбора
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: context.dynamicPrimaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            (state.selectedMediaIds.toList().indexOf(mediaItem.id) + 1).toString(),
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Индикатор видео
                  if (mediaItem.isVideo)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.videocam,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // Затемнение если превышен лимит
                  if (!isSelected && state.selectedCount >= widget.maxSelection)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Создает виджет пустого состояния
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library,
            size: 48,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'Фото и видео не найдены',
            style: AppTextStyles.h3.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавьте фото и видео в галерею устройства',
            style: AppTextStyles.bodyMedium.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Создает индикатор загрузки для пагинации
  Widget _buildLoadingIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
