import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/services/api_client/dio_client.dart';
import 'package:kconnect_mobile/services/cache/video_cache_service.dart';

/// Экран полноэкранного просмотра медиа
///
/// Отображает фото и видео в полноэкранном режиме с поддержкой зума
class MediaViewerScreen extends StatefulWidget {
  final String? photoUrl;
  final String? videoUrl;
  final String? title;

  const MediaViewerScreen({
    super.key,
    this.photoUrl,
    this.videoUrl,
    this.title,
  }) : assert(photoUrl != null || videoUrl != null, 'Either photoUrl or videoUrl must be provided');

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl != null) {
      _initVideoPlayer();
    } else {
      _isLoading = false;
    }
  }

  Future<void> _initVideoPlayer() async {
    try {
      final videoUrl = widget.videoUrl;
      if (videoUrl == null) return;

      // Get theme values before async operations
      final colorScheme = Theme.of(context).colorScheme;
      final primaryColor = context.dynamicPrimaryColor;

      final fullUrl = videoUrl.startsWith('http') ? videoUrl : 'https://k-connect.ru$videoUrl';

      // Пытаемся использовать кэшированный файл
      try {
        final videoCacheService = VideoCacheService.instance;
        final cachedFile = await videoCacheService.getCachedVideoFile(fullUrl);

        // Проверяем, что файл существует и не пустой
        if (await cachedFile.exists() && await cachedFile.length() > 0) {
          // Используем кэшированный файл
          _videoController = VideoPlayerController.file(cachedFile);
        } else {
          // Файл не существует или пустой - используем прямое воспроизведение
          _videoController = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
        }
      } catch (cacheError) {
        // Ошибка кэширования - используем прямое воспроизведение из сети
        _videoController = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      }

      await _videoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: colorScheme.primary,
          handleColor: colorScheme.primary,
          backgroundColor: colorScheme.primary.withValues(alpha: 0.2),
          bufferedColor: colorScheme.primary.withValues(alpha: 0.5),
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(
              color: primaryColor,
            ),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки видео',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        },
      );

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('MediaViewerScreen: Error initializing video player: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  String? _getFullUrl(String? url) {
    if (url == null) return null;
    if (url.startsWith('http')) return url;
    return 'https://k-connect.ru$url';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: widget.title != null
            ? Text(
                widget.title!,
                style: const TextStyle(color: Colors.white),
              )
            : null,
        actions: [
          if (widget.photoUrl != null || widget.videoUrl != null)
            IconButton(
              icon: const Icon(Icons.download, color: Colors.white),
              onPressed: () {
                // TODO: Implement save media to gallery
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Сохранение медиа будет реализовано позже'),
                    backgroundColor: Colors.black54,
                  ),
                );
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: context.dynamicPrimaryColor,
              ),
            )
          : widget.photoUrl != null
              ? FutureBuilder<Map<String, String>>(
                  future: _getAuthHeaders(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: context.dynamicPrimaryColor,
                        ),
                      );
                    }

                    final headers = snapshot.hasData ? snapshot.data! : <String, String>{};
                    final fullUrl = _getFullUrl(widget.photoUrl);

                    return PhotoView(
                      imageProvider: CachedNetworkImageProvider(
                        fullUrl!,
                        headers: headers.isNotEmpty ? headers : null,
                      ),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 2,
                      initialScale: PhotoViewComputedScale.contained,
                      heroAttributes: PhotoViewHeroAttributes(tag: widget.photoUrl!),
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white, size: 48),
                              const SizedBox(height: 16),
                              const Text(
                                'Ошибка загрузки изображения',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        );
                      },
                      loadingBuilder: (context, event) {
                        if (event == null) {
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        }
                        return Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            value: event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                          ),
                        );
                      },
                    );
                  },
                )
              : widget.videoUrl != null && _chewieController != null
                  ? Center(
                      child: Chewie(controller: _chewieController!),
                    )
                  : Center(
                      child: Text(
                        'Медиа не найдено',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
    );
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final dioClient = DioClient();
      final requiresAuth = widget.photoUrl != null && 
          (widget.photoUrl!.contains('/apiMes/') || widget.photoUrl!.contains('/api/messenger/'));
      if (requiresAuth) {
        return await dioClient.getImageAuthHeaders();
      }
      return {};
    } catch (e) {
      debugPrint('MediaViewerScreen: Error getting auth headers: $e');
      return {};
    }
  }
}
