/// Мини-плеер с анимацией раскрытия и управления воспроизведением
///
/// Плавающий плеер в нижней части экрана с эффектом жидкого стекла.
/// Поддерживает анимацию раскрытия для показа дополнительных контролов.
/// Работает напрямую со стримами AudioService как в официальных примерах.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import '../presentation/blocs/queue_bloc.dart';
import '../presentation/blocs/queue_event.dart';
import '../domain/models/queue_state.dart';
import '../domain/models/track.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/core/utils/image_utils.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../../../services/audio_service_manager.dart';
import '../../../../core/widgets/glass_mode_wrapper.dart';

/// Виджет мини-плеера с анимацией раскрытия
///
/// Показывает текущий трек, прогресс и элементы управления.
/// Поддерживает плавную анимацию между свернутым и развернутым состояниями.
/// Работает напрямую со стримами AudioService как в официальных примерах.
class MiniPlayer extends StatefulWidget {
  final VoidCallback? onMusicTabTap;
  final Function(bool hide)? onTabBarToggle;

  const MiniPlayer({super.key, this.onMusicTabTap, this.onTabBarToggle});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

/// Состояние медиа для комбинирования MediaItem и позиции
class _MediaState {
  final MediaItem? mediaItem;
  final Duration position;
  final bool playing;
  final bool isBuffering;

  _MediaState(this.mediaItem, this.position, this.playing, this.isBuffering);

  Track? get track {
    if (mediaItem == null) return null;
    final trackId = mediaItem!.extras?['trackId'] as int?;
    if (trackId == null) return null;
    return Track(
      id: trackId,
      title: mediaItem!.title,
      artist: mediaItem!.artist ?? '',
      durationMs: mediaItem!.duration?.inMilliseconds ?? 0,
      coverPath: mediaItem!.extras?['coverPath'] as String?,
      filePath: mediaItem!.extras?['originalUrl'] as String? ?? mediaItem!.id,
      isLiked: mediaItem!.extras?['isLiked'] as bool? ?? false,
    );
  }

  double get progress {
    final duration = mediaItem?.duration;
    if (duration == null || duration.inSeconds == 0) return 0.0;
    return position.inSeconds / duration.inSeconds;
  }
}

class _MiniPlayerState extends State<MiniPlayer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _positionAnimation;
  late Animation<double> _widthAnimation;
  late Animation<double> _heightAnimation;
  late Animation<double> _borderRadiusAnimation;
  late Animation<double> _albumArtPositionAnimation;
  late Animation<double> _contentOpacityAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

  }

  void _setupAnimations(double screenWidth) {
    final expandedWidth = screenWidth - 32;
    _positionAnimation = Tween<double>(begin: 12, end: 12).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)
    );
    _widthAnimation = Tween<double>(begin: 50, end: expandedWidth).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)
    );
    _heightAnimation = Tween<double>(begin: 50, end: 50).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)
    );
    _borderRadiusAnimation = Tween<double>(begin: 25, end: 25).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)
    );
    _albumArtPositionAnimation = Tween<double>(begin: 3, end: 4).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic)
    );
    _contentOpacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Interval(0.3, 1.0, curve: Curves.easeOut))
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      widget.onTabBarToggle?.call(_isExpanded);
    });
  }

  void _handlePlayPause() {
    final handler = AudioServiceManager.getHandler();
    if (handler == null) {
      return;
    }
    
    // Используем handler напрямую для получения текущего состояния
    final currentState = handler.playbackState.valueOrNull;
    final isPlaying = currentState?.playing ?? false;
    
    if (isPlaying) {
      handler.pause();
    } else {
      handler.play();
    }
  }

  void _handleNext(BuildContext context) {
    context.read<QueueBloc>().add(const QueueNextRequested());
  }

  void _handlePrevious(BuildContext context) {
    context.read<QueueBloc>().add(const QueuePreviousRequested());
  }

  /// Комбинированный стрим для медиа-элемента, позиции и состояния воспроизведения
  Stream<_MediaState> get _mediaStateStream {
    // Пробуем получить handler напрямую для доступа к mediaItem
    final handler = AudioServiceManager.getHandler();
    
    // Используем handler.mediaItem если доступен (это ValueStream)
    // Иначе используем AudioService.currentMediaItemStream
    Stream<MediaItem?> mediaItemStream;
    if (handler != null) {
      // handler.mediaItem - это ValueStream, используем его напрямую
      final initialValue = handler.mediaItem.valueOrNull;
      if (kDebugMode) {
        debugPrint('MiniPlayer: Using handler.mediaItem, initial value: ${initialValue?.title}');
      }
      // Используем ValueStream напрямую с начальным значением
      mediaItemStream = handler.mediaItem.startWith(initialValue);
    } else {
      // Fallback when handler is not available - create a stream that emits null initially
      if (kDebugMode) {
        debugPrint('MiniPlayer: Using fallback stream (null)');
      }
      mediaItemStream = Stream.value(null);
    }
    
    final positionStream = AudioService.position.startWith(Duration.zero);
    
    // Используем handler напрямую для playing, если доступен (как в MainTabs)
    Stream<bool> playingStream;
    Stream<bool> bufferingStream;
    
    if (handler != null) {
      final initialPlaybackState = handler.playbackState.valueOrNull;
      final initialPlaying = initialPlaybackState?.playing ?? false;
      final initialBuffering = initialPlaybackState?.processingState == AudioProcessingState.buffering;

      playingStream = handler.playbackState
          .map((state) => state.playing)
          .distinct()
          .startWith(initialPlaying);
      bufferingStream = handler.playbackState
          .map((state) => state.processingState == AudioProcessingState.buffering)
          .distinct()
          .startWith(initialBuffering);
    } else {
      // Fallback when handler is not available - create streams that emit default values
      playingStream = Stream.value(false);
      bufferingStream = Stream.value(false);
    }
    
    return Rx.combineLatest4<MediaItem?, Duration, bool, bool, _MediaState>(
      mediaItemStream,
      positionStream,
      playingStream,
      bufferingStream,
      (mediaItem, position, playing, isBuffering) {
        return _MediaState(mediaItem, position, playing, isBuffering);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    _setupAnimations(MediaQuery.of(context).size.width);

    return BlocListener<QueueBloc, QueueState>(
      listener: (context, queueState) {
        // Очередь синхронизируется автоматически через MediaPlayerService
        // Воспроизведение запускается автоматически при создании очереди
      },
      child: StreamBuilder<_MediaState>(
        stream: _mediaStateStream,
        builder: (context, snapshot) {
          final mediaState = snapshot.data;
          final hasTrack = mediaState?.track != null;
          final track = mediaState?.track;
          
          
          widget.onTabBarToggle?.call(hasTrack && _isExpanded);

          Widget miniPlayerContent = AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => Positioned(
              bottom: 16,
              left: _positionAnimation.value,
              child: GlassModeWrapper(
                borderRadius: _borderRadiusAnimation.value,
                settings: const LiquidGlassSettings(
                  thickness: 15,
                  glassColor: Color(0x33FFFFFF),
                  lightIntensity: 1.5,
                  chromaticAberration: 1,
                  saturation: 1.1,
                  ambientStrength: 1,
                  blur: 4,
                  refractiveIndex: 1.8,
                ),
                child: SizedBox(
                  key: ValueKey('miniPlayer_${track?.id ?? 'idle'}_$_isExpanded'),
                  width: _widthAnimation.value,
                  height: _heightAnimation.value,
                  child: !hasTrack
                      ? _buildMusicTabButton(mediaState)
                      : _buildAnimatedView(context, mediaState!),
                ),
              ),
            ),
          );

          // Кружок прогресса вокруг кнопки мини плеера (показывается всегда, когда есть трек)
          if (hasTrack) {
            final overlay = AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => Positioned(
                bottom: 16 - 3 * (1 - _animationController.value),
                left: 12 - 3 * (1 - _animationController.value),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 1 - _animationController.value,
                    child: Transform.scale(
                      scale: 1 - _animationController.value,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: mediaState!.progress.clamp(0.0, 1.0),
                          strokeWidth: 3,
                          backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(context.dynamicPrimaryColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );

            return Stack(
              children: [
                miniPlayerContent,
                overlay,
              ],
            );
          }

          return miniPlayerContent;
        },
      ),
    );
  }



  Widget _buildMusicTabButton(_MediaState? mediaState) {
    final hasTrack = mediaState?.track != null;
    final progress = mediaState?.progress ?? 0.0;

    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      iconSize: 24,
      color: Theme.of(context).colorScheme.onSurfaceVariant, // Явно задаем цвет для IconButton
      onPressed: widget.onMusicTabTap,
      icon: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.music_note,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant, // Цвет неактивных кнопок таб-бара
          ),
          if (hasTrack) // Показываем кружок, если есть трек (независимо от playing)
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                strokeWidth: 2,
                backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(context.dynamicPrimaryColor),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAnimatedView(BuildContext context, _MediaState mediaState) {
    final track = mediaState.track!;
    final duration = mediaState.mediaItem?.duration;
    final progress = mediaState.progress;
    final trackDuration = duration; // Сохраняем для использования в условии

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(
          color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(_borderRadiusAnimation.value),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background tap area - covers entire container except controls
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleExpand, // Background tap closes the player
              behavior: HitTestBehavior.translucent,
              child: Container(
                color: Colors.transparent, // Transparent background
              ),
            ),
          ),

          // Album art that animates from center to left
          Positioned(
            left: _albumArtPositionAnimation.value,
            child: GestureDetector(
              onTap: _toggleExpand, // Album art tap also closes
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CachedNetworkImage(
                  imageUrl: ImageUtils.getCompleteImageUrl(track.coverPath) ?? '',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 40,
                    height: 40,
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                    child: CircularProgressIndicator(
                      color: context.dynamicPrimaryColor,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 40,
                    height: 40,
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.2),
                    child: Icon(
                      Icons.music_note,
                      color: context.dynamicPrimaryColor,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Expanded content that fades in
          Opacity(
            opacity: _contentOpacityAnimation.value,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Spacer to account for album art
                  const SizedBox(width: 48), // 40px art + 8px margin
                  // Track info - background tappable
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleExpand, // Track info tap closes player
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2), // Small top padding
                          Text(
                            track.title,
                            style: AppTextStyles.postAuthor.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            track.artist,
                            style: AppTextStyles.bodySecondary.copyWith(
                              fontSize: 10,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Controls - positioned above background with higher z-index
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Previous track button
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _handlePrevious(context),
                        icon: Icon(
                          Icons.skip_previous,
                          color: context.dynamicPrimaryColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: mediaState.isBuffering ? null : _handlePlayPause,
                        icon: _buildPlayAnimatedIcon(context, mediaState.playing, mediaState.isBuffering),
                      ),
                      const SizedBox(width: 4),
                      // Next track button
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _handleNext(context),
                        icon: Icon(
                          Icons.skip_next,
                          color: context.dynamicPrimaryColor,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: _toggleExpand,
                        icon: Icon(
                          _isExpanded ? Icons.expand_more : Icons.vertical_align_top,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Progress bar at bottom of container
          if (trackDuration != null && trackDuration > Duration.zero)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTapDown: (details) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPosition = box.globalToLocal(details.globalPosition);
                    final tapProgress = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
                    final newPosition = Duration(
                      seconds: (trackDuration.inSeconds * tapProgress).round()
                    );
                    final handler = AudioServiceManager.getHandler();
                    if (handler != null) {
                      handler.seek(newPosition).catchError((e) {
                        // Ignore seek errors
                      });
                    } else {
                      // Fallback when handler is not available - cannot seek without handler
                      // This is a no-op since seeking requires an active audio handler
                    }
                  }
                },
                child: Container(
                  height: 2,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.dynamicPrimaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }



  Widget _buildPlayAnimatedIcon(BuildContext context, bool isPlaying, bool isBuffering) {
    final primaryColor = context.dynamicPrimaryColor;
    if (isBuffering) {
      return CircularProgressIndicator(
        color: primaryColor,
      );
    }
    if (!isPlaying) {
      return Icon(
        Icons.play_arrow,
        color: primaryColor,
        size: 16,
      );
    }
    return Icon(
      Icons.pause,
      color: primaryColor,
      size: 20,
    );
  }
}
