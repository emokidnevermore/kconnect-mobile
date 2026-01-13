/// Мини-плеер с анимацией раскрытия и управления воспроизведением
///
/// Плавающий плеер в нижней части экрана с эффектом жидкого стекла.
/// Поддерживает анимацию раскрытия для показа дополнительных контролов.
/// Работает напрямую со стримами AudioService как в официальных примерах.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import '../presentation/blocs/queue_bloc.dart';
import '../presentation/blocs/queue_event.dart';
import '../domain/models/queue_state.dart';
import '../presentation/blocs/music_bloc.dart';
import '../presentation/blocs/music_event.dart';
import '../domain/models/track.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/theme/app_colors.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/core/utils/image_utils.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../../../services/audio_service_manager.dart';
import '../../../../core/widgets/glass_mode_wrapper.dart';
import '../../../../services/storage_service.dart';

/// Виджет мини-плеера с анимацией раскрытия
///
/// Показывает текущий трек, прогресс и элементы управления.
/// Поддерживает плавную анимацию между свернутым и развернутым состояниями.
/// Работает напрямую со стримами AudioService как в официальных примерах.
class MiniPlayer extends StatefulWidget {
  final VoidCallback? onMusicTabTap;
  final Function(bool hide)? onTabBarToggle;
  final VoidCallback? onFullScreenTap;

  const MiniPlayer({
    super.key,
    this.onMusicTabTap,
    this.onTabBarToggle,
    this.onFullScreenTap,
  });

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
  late Animation<double> _absorbAnimation;
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
    _absorbAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut)
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

  void _handleLike(BuildContext context, Track track) {
    context.read<MusicBloc>().add(MusicTrackLiked(track.id, track));
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
              child: !hasTrack
                  ? _buildMusicTabButton(mediaState) // Show button when no track
                  : GlassModeWrapper(
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
                        child: _buildAnimatedView(context, mediaState!),
                      ),
                    ),
            ),
          );

          // Кружок прогресса вокруг обложки трека (показывается всегда, когда есть трек)
          if (hasTrack) {
            final overlay = AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => Positioned(
                bottom: 20,
                left: 13 + _albumArtPositionAnimation.value, // Позиционируем вокруг обложки
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - _absorbAnimation.value * 1.2).clamp(0.0, 1.0), // Clamp to valid range
                    child: SizedBox(
                      width: 44,
                      height: 44,
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

    return GlassModeWrapper(
      borderRadius: 25,
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
        width: 50,
        height: 50,
        child: IconButton(
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
        ),
      ),
    );
  }

  Widget _buildAnimatedView(BuildContext context, _MediaState mediaState) {
    final track = mediaState.track!;

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
          // Album art that animates from center to left
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) => Positioned(
              left: _albumArtPositionAnimation.value,
              child: GestureDetector(
                onTap: _toggleExpand,
                  child: Hero(
                    tag: 'album_art_${track.id}',
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
            ),
          ),

          // Background tap area - covers entire container except controls
          FutureBuilder<bool>(
            future: StorageService.getInvertPlayerTapBehavior(),
            builder: (context, snapshot) {
              final invert = snapshot.data ?? false;
              return GestureDetector(
                onTap: invert ? widget.onFullScreenTap : _toggleExpand, // Swap based on setting
                onLongPress: invert ? _toggleExpand : widget.onFullScreenTap, // Swap based on setting
                behavior: HitTestBehavior.translucent,
                child: Container(
                  color: Colors.transparent, // Transparent background
                ),
              );
            },
          ),

          // Expanded content that fades in
          Opacity(
            opacity: _contentOpacityAnimation.value,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Spacer to account for album art
                  const SizedBox(width: 52), // More space from album art
                  // Track info - background tappable
                  Expanded(
                    child: GestureDetector(
                      onTap: _toggleExpand, // Track info tap closes player
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4), // Top padding
                          Text(
                            track.title,
                            style: AppTextStyles.postAuthor.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.1, // Reduce line height
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            track.artist,
                            style: AppTextStyles.bodySecondary.copyWith(
                              fontSize: 10,
                              height: 1.1, // Reduce line height
                              color: AppColors.textSecondary.withValues(alpha: 0.7), // Slightly more muted
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Controls - positioned with some right margin, not at the very end
                  Padding(
                    padding: const EdgeInsets.only(right: 12), // Add right margin
                    child: Row(
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
                        const SizedBox(width: 1), // Tighter spacing
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: mediaState.isBuffering ? null : _handlePlayPause,
                          icon: _buildPlayAnimatedIcon(context, mediaState.playing, mediaState.isBuffering),
                        ),
                        const SizedBox(width: 1), // Tighter spacing
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
                        const SizedBox(width: 26), // More spacing between controls and like
                        _AnimatedMiniPlayerLikeButton(
                          isLiked: track.isLiked,
                          onTap: () => _handleLike(context, track),
                        ),
                      ],
                    ),
                  ),
                ],
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
      return SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: primaryColor,
        ),
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

/// Анимированная кнопка лайка для мини-плеера с spring эффектом
class _AnimatedMiniPlayerLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback? onTap;

  const _AnimatedMiniPlayerLikeButton({
    required this.isLiked,
    this.onTap,
  });

  @override
  State<_AnimatedMiniPlayerLikeButton> createState() => _AnimatedMiniPlayerLikeButtonState();
}

class _AnimatedMiniPlayerLikeButtonState extends State<_AnimatedMiniPlayerLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Scale animation with spring effect
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50.0,
      ),
    ]).animate(_animationController);

    // Color animation
    _colorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Set initial state
    if (widget.isLiked) {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_AnimatedMiniPlayerLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update animation state if liked status changed externally
    if (widget.isLiked != oldWidget.isLiked) {
      if (widget.isLiked) {
        _animationController.forward();
        HapticFeedback.lightImpact();
      } else {
        _animationController.reverse();
      }
    }
  }

  void _handleTap() {
    if (widget.onTap == null) return;

    // Haptic feedback
    HapticFeedback.lightImpact();

    // Trigger animation immediately
    final willBeLiked = !widget.isLiked;
    if (willBeLiked) {
      _animationController.forward(from: 0.0);
    } else {
      _animationController.reverse(from: 1.0);
    }

    // Call the callback
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          // Interpolate color between unliked and liked state
          final likedColor = context.dynamicPrimaryColor;
          final unlikedColor = AppColors.textSecondary;
          final animatedColor = Color.lerp(
            unlikedColor,
            likedColor,
            _colorAnimation.value,
          ) ?? unlikedColor;

          // Interpolate between border and filled icon
          final icon = _colorAnimation.value > 0.5
              ? Icons.favorite
              : Icons.favorite_border;

          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Icon(
              icon,
              size: 16,
              color: animatedColor,
            ),
          );
        },
      ),
    );
  }
}
