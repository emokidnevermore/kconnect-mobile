/// Просмотрщик медиа-контента
///
/// Виджет для просмотра галереи изображений и видео.
/// Поддерживает зум, панорамирование, полноэкранный режим.
/// Включает элементы управления видео и навигацию между элементами.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:video_player/video_player.dart';
import '../../services/cache/video_cache_service.dart';
import '../../theme/app_text_styles.dart';
import '../media_item.dart';

/// Виджет для просмотра медиа-галереи
///
/// Позволяет просматривать изображения и видео в полноэкранном режиме
/// с поддержкой зума, панорамирования и навигации между элементами.
class MediaViewer extends StatefulWidget {
  /// Список медиа-элементов для просмотра
  final List<MediaItem> items;

  /// Индекс начального элемента для отображения
  final int initialIndex;
  
  /// Префикс для Hero тегов (для различения постов в ленте и профиле)
  final String? heroTagPrefix;
  
  /// ID поста для уникальности Hero тегов (необходимо для предотвращения дубликатов)
  final int? postId;
  
  /// Индекс поста в ленте для уникальности Hero тегов (необходимо для предотвращения дубликатов)
  final int? feedIndex;

  /// Конструктор просмотрщика медиа
  const MediaViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.heroTagPrefix,
    this.postId,
    this.feedIndex,
  });

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

/// Состояние виджета MediaViewer
class _MediaViewerState extends State<MediaViewer> {
  /// Текущий индекс отображаемого элемента
  late int _currentIndex;

  /// Контроллеры Chewie для видео-плееров
  final Map<int, ChewieController?> _chewieControllers = {};

  /// Контроллеры VideoPlayer для видео
  final Map<int, VideoPlayerController?> _videoControllers = {};

  /// Набор индексов видео, которые не удалось загрузить
  final Set<int> _failedVideoIndices = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;

    if (widget.items.isNotEmpty && widget.items[_currentIndex].isVideo) {
      _initializeVideo(_currentIndex);
    }
  }

  @override
  void dispose() {
    _chewieControllers.values.where((c) => c != null).forEach((c) => c!.dispose());
    _videoControllers.values.where((c) => c != null).forEach((c) => c!.dispose());

    super.dispose();
  }

  /// Инициализация видео-контроллера для указанного индекса
  ///
  /// Создает VideoPlayerController и ChewieController для видео.
  /// Использует кэшированные видео файлы для постоянного хранения.
  /// При ошибке кэширования использует прямое воспроизведение из сети.
  /// Обрабатывает ошибки загрузки и помечает неудачные загрузки.
  void _initializeVideo(int index) async {
    if (!_videoControllers.containsKey(index) && widget.items[index].isVideo) {
      final item = widget.items[index];

      try {
        VideoPlayerController videoController;
        
        // Пытаемся использовать кэшированный файл
        try {
          final videoCacheService = VideoCacheService.instance;
          final cachedFile = await videoCacheService.getCachedVideoFile(item.url);
          
          // Проверяем, что файл существует и не пустой
          if (await cachedFile.exists() && await cachedFile.length() > 0) {
            // Используем кэшированный файл
            videoController = VideoPlayerController.file(cachedFile);
          } else {
            // Файл не существует или пустой - используем прямое воспроизведение
            videoController = VideoPlayerController.networkUrl(Uri.parse(item.url));
          }
        } catch (cacheError) {
          // Ошибка кэширования - используем прямое воспроизведение из сети
          if (kDebugMode) {
            debugPrint('MediaViewer: Video cache error for ${item.url}: $cacheError');
          }
          videoController = VideoPlayerController.networkUrl(Uri.parse(item.url));
        }
        
        _videoControllers[index] = videoController;

        await videoController.initialize();

        if (mounted) {
          final chewieController = ChewieController(
            videoPlayerController: videoController,
            autoPlay: false,
            looping: false,
            showControls: true,
            aspectRatio: videoController.value.aspectRatio,
            placeholder: const SizedBox.shrink(),
            errorBuilder: (context, _) => Center(
              child: Icon(
                Icons.warning,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 48,
              ),
            ),
          );
          _chewieControllers[index] = chewieController;
          setState(() {});
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('MediaViewer: Error initializing video at index $index: $e');
          debugPrint('MediaViewer: Stack trace: $stackTrace');
        }
        if (mounted) {
          _failedVideoIndices.add(index);
          setState(() {});
        }
      }
    }
  }

  /// Обработчик изменения страницы в галерее
  ///
  /// Обновляет текущий индекс, останавливает предыдущие видео
  /// и инициализирует видео для текущей страницы.
  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pauseAllVideos();
    if (widget.items[index].isVideo) {
      if (_chewieControllers[index] == null) {
        _initializeVideo(index);
      } else {
        _videoControllers[index]?.play();
      }
    }
    final nextIndex = index + 1;
    if (nextIndex < widget.items.length && widget.items[nextIndex].isVideo && !_videoControllers.containsKey(nextIndex)) {
      _initializeVideo(nextIndex);
    }
  }

  /// Останавливает все активные видео
  void _pauseAllVideos() {
    for (final controller in _videoControllers.values) {
      controller?.pause();
    }
  }

  /// Создает виджет для отображения видео-элемента
  ///
  /// Возвращает Chewie плеер для загруженного видео или
  /// заполнители для состояний загрузки/ошибки.
  Widget _buildVideoItem(MediaItem item, int index) {
    if (_failedVideoIndices.contains(index)) {
      // Не удалось загрузить видео
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки видео',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final chewieController = _chewieControllers[index];
    final videoController = _videoControllers[index];
    
    // Проверяем, инициализируется ли видео
    if (videoController != null && !videoController.value.isInitialized) {
      // Видео загружается
      return Stack(
        fit: StackFit.expand,
        children: [
          if (item.posterUrl != null)
            CachedNetworkImage(
              imageUrl: item.posterUrl!,
              fit: BoxFit.contain,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (_, _, _) => Container(
                color: Colors.black,
              ),
            ),
          if (item.posterUrl == null)
            Container(
              color: Colors.black,
            ),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }
    
    if (chewieController != null && videoController?.value.isInitialized == true) {
      return Chewie(controller: chewieController);
    } else {
      // Видео еще не инициализировано - показываем постер и индикатор загрузки
      return Stack(
        fit: StackFit.expand,
        children: [
          if (item.posterUrl != null)
            CachedNetworkImage(
              imageUrl: item.posterUrl!,
              fit: BoxFit.contain,
              placeholder: (_, _) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorWidget: (_, _, _) => Container(
                color: Colors.black,
              ),
            ),
          if (item.posterUrl == null)
            Container(
              color: Colors.black,
            ),
          const Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final item = widget.items[_currentIndex];

    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // PhotoViewGallery
            PhotoViewGallery.builder(
              itemCount: widget.items.length,
              pageController: PageController(initialPage: widget.initialIndex),
              builder: (context, index) {
                final mediaItem = widget.items[index];

                if (mediaItem.isImage) {
                  // Hero tag для анимации
                  // Используем heroTagPrefix если передан, иначе определяем автоматически
                  final isProfileAvatar = mediaItem.url.contains('/avatar/');
                  final prefix = widget.heroTagPrefix ?? (isProfileAvatar ? 'profile_avatar' : 'post_media');
                  // Используем postId и feedIndex для уникальности, если они доступны
                  final postIdSuffix = widget.postId != null ? '_${widget.postId}' : '';
                  final feedIndexSuffix = widget.feedIndex != null ? '_feed${widget.feedIndex}' : '';
                  final heroTag = '${prefix}_${mediaItem.url.hashCode}_$index$postIdSuffix$feedIndexSuffix';
                  
                  // Пользовательская обработка изображений с резервом при ошибке
                  return PhotoViewGalleryPageOptions.customChild(
                    child: Hero(
                      tag: heroTag,
                      transitionOnUserGestures: true,
                      child: Material(
                        color: Colors.transparent,
                        child: CachedNetworkImage(
                          imageUrl: mediaItem.url,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorWidget: (context, url, error) {
                            // Проверяем, является ли это ошибкой 403 или другой, показываем плейсхолдер аватара
                            if (mediaItem.url.contains('/avatar/')) {
                              return CachedNetworkImage(
                                imageUrl: 'https://k-connect.ru/static/uploads/system/album_placeholder.jpg',
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.black,
                                  child: Center(
                                    child: Icon(
                                      Icons.photo,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              // Для других ошибок изображений показываем общую ошибку
                              return Container(
                                color: Colors.black,
                                child: Center(
                                  child: Icon(
                                    Icons.photo,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    size: 48,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 4.0,
                    initialScale: PhotoViewComputedScale.contained,
                  );
                } else {
                  // Для видео используем Hero тег на основе posterUrl (если есть) или URL
                  // Это важно для совпадения с Hero тегом в PostMedia
                  final heroUrl = mediaItem.posterUrl ?? mediaItem.url;
                  // Используем heroTagPrefix если передан, иначе определяем автоматически
                  final isProfileAvatar = heroUrl.contains('/avatar/');
                  final prefix = widget.heroTagPrefix ?? (isProfileAvatar ? 'profile_avatar' : 'post_media');
                  // Используем postId и feedIndex для уникальности, если они доступны
                  final postIdSuffix = widget.postId != null ? '_${widget.postId}' : '';
                  final feedIndexSuffix = widget.feedIndex != null ? '_feed${widget.feedIndex}' : '';
                  final heroTag = '${prefix}_${heroUrl.hashCode}_$index$postIdSuffix$feedIndexSuffix';
                  
                  // Пользовательский дочерний элемент для видео с Hero анимацией
                  return PhotoViewGalleryPageOptions.customChild(
                    child: Hero(
                      tag: heroTag,
                      transitionOnUserGestures: true,
                      child: Material(
                        color: Colors.transparent,
                        child: _buildVideoItem(mediaItem, index),
                      ),
                    ),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.contained,
                    initialScale: PhotoViewComputedScale.contained,
                  );
                }
              },
              onPageChanged: _onPageChanged,
              scrollPhysics: const BouncingScrollPhysics(),
              backgroundDecoration: const BoxDecoration(
                color: Colors.black,
              ),
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(),
              ),
            ),

            // Оверлей: Кнопка назад и счетчик
            Positioned(
              top: 20,
              left: 16,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            // Счетчик
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(128),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.items.length}',
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            if (item.isVideo && _videoControllers[_currentIndex]?.value.isInitialized == false)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: const Center(
                  child: Text(
                    'Нажмите для воспроизведения',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
