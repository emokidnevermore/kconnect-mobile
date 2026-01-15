/// Полноэкранный плеер для музыки
///
/// Показывает текущий трек в полноэкранном режиме с обложкой,
/// информацией о треке, seek полосой и кнопками управления.
/// Поддерживает плавные анимации и Material Design 3 стиль.
library;

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';
import '../presentation/blocs/queue_bloc.dart';
import '../presentation/blocs/queue_event.dart';
import '../domain/models/queue_state.dart';
import '../presentation/blocs/music_bloc.dart';
import '../presentation/blocs/music_event.dart';
import '../domain/models/track.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../core/utils/image_utils.dart';
import '../../../services/audio_service_manager.dart';
import '../../../services/image_palette_service.dart';
import '../../../services/lyrics_service.dart';
import '../domain/models/lyrics.dart';

/// Параметры для плавающего кружка
class _FloatingCircleParams {
  final double size;
  final double speedX;
  final double speedY;
  final double amplitudeX;
  final double amplitudeY;
  final double phaseX;
  final double phaseY;
  final Offset basePosition;

  const _FloatingCircleParams({
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.amplitudeX,
    required this.amplitudeY,
    required this.phaseX,
    required this.phaseY,
    required this.basePosition,
  });
}

/// Виджет полноэкранного плеера
///
/// Показывает текущий трек в полноэкранном режиме с:
/// - Большой обложкой альбома
/// - Названием трека и исполнителем
/// - Seek полосой с прогрессом
/// - Кнопками управления воспроизведением
class FullScreenPlayer extends StatefulWidget {
  const FullScreenPlayer({super.key});

  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

/// InheritedWidget для передачи режима лирики
class _LyricsModeInherited extends InheritedWidget {
  final ValueNotifier<bool> isLyricsModeNotifier;

  const _LyricsModeInherited({
    required this.isLyricsModeNotifier,
    required super.child,
  });

  static _LyricsModeInherited? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_LyricsModeInherited>();
  }

  @override
  bool updateShouldNotify(_LyricsModeInherited oldWidget) {
    return oldWidget.isLyricsModeNotifier != isLyricsModeNotifier;
  }
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

class _FullScreenPlayerState extends State<FullScreenPlayer>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideUpAnimation;

  LinearGradient? _currentGradient;
  late AnimationController _floatingAnimationController;
  late List<_FloatingCircleParams> _floatingCircles;
  String? _currentTrackCoverUrl;
  Color? _trackAccentColor; // Акцентный цвет для элементов управления

  // Состояние лирики
  LyricsData? _lyricsData;
  final ValueNotifier<bool> _isLyricsModeNotifier = ValueNotifier(false); // Режим отображения лирики
  int? _currentTrackId; // ID текущего трека для отслеживания изменений

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _slideUpAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Инициализация анимаций плавания
    _floatingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );

    // Инициализируем пустой список, он будет заполнен при обновлении градиента
    _floatingCircles = [];

    // Запускаем анимации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      _floatingAnimationController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _floatingAnimationController.dispose();
    super.dispose();
  }

  void _handlePlayPause() {
    final handler = AudioServiceManager.getHandler();
    if (handler == null) return;

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

  void _handleSeek(double value, Duration totalDuration) {
    final position = Duration(seconds: (value * totalDuration.inSeconds).toInt());
    final handler = AudioServiceManager.getHandler();
    handler?.seek(position);
  }

  /// Загружает лирику для текущего трека
  Future<void> _loadLyrics(int trackId) async {
    try {
      final lyricsService = LyricsService();
      final lyricsData = await lyricsService.getLyrics(trackId);

      if (mounted) {
        setState(() {
          _lyricsData = lyricsData;
        });
      }
    } catch (e) {
      debugPrint('Failed to load lyrics for track $trackId: $e');
      if (mounted) {
        setState(() {
          _lyricsData = LyricsData(
            hasLyrics: false,
            hasSyncedLyrics: false,
            trackId: trackId,
          );
        });
      }
    }
  }

  /// Переключает режим отображения (обложка/лирика)
  void _toggleLyricsMode() {
    _isLyricsModeNotifier.value = !_isLyricsModeNotifier.value;
  }

  /// Обновляет градиент фона на основе цветов обложки трека и генерирует плавающие кружки
  Future<void> _updateGradientForTrack(String coverUrl, Track track) async {
    try {
      final paletteService = ImagePaletteService();
      final palette = await paletteService.getPalette(coverUrl);

      if (mounted) {
        // Генерируем уникальные параметры анимации для трека
        final trackSeed = track.id.hashCode + track.durationMs;
        final random = Random(trackSeed);

        // Количество кружков: 3-8
        final circleCount = 3 + (trackSeed % 6);

        final circles = List.generate(circleCount, (index) {
          final size = 100.0 + random.nextDouble() * 300.0; // 100-400 пикселей
          final speedX = 0.3 + random.nextDouble() * 1.5; // 0.3-1.8x скорость
          final speedY = 0.2 + random.nextDouble() * 1.3; // 0.2-1.5x скорость
          final amplitudeX = 15.0 + random.nextDouble() * 40.0; // 15-55 пикселей (уменьшено)
          final amplitudeY = 12.0 + random.nextDouble() * 35.0; // 12-47 пикселей (уменьшено)
          final phaseX = random.nextDouble() * 2 * pi;
          final phaseY = random.nextDouble() * 2 * pi;

          // Базовые позиции для размещения кружков вокруг экрана
          final positions = [
            Offset(-size/2, -size/2), // Левый верхний угол
            Offset(MediaQuery.of(context).size.width - size/2, -size/2), // Правый верхний
            Offset(-size/2, MediaQuery.of(context).size.height/2 - size/2), // Левый центр
            Offset(MediaQuery.of(context).size.width - size/2, MediaQuery.of(context).size.height/2 - size/2), // Правый центр
            Offset(-size/2, MediaQuery.of(context).size.height - size/2), // Левый нижний
            Offset(MediaQuery.of(context).size.width - size/2, MediaQuery.of(context).size.height - size/2), // Правый нижний
            Offset(MediaQuery.of(context).size.width/2 - size/2, -size/2), // Верхний центр
            Offset(MediaQuery.of(context).size.width/2 - size/2, MediaQuery.of(context).size.height - size/2), // Нижний центр
          ];

          final basePosition = positions[index % positions.length];

          return _FloatingCircleParams(
            size: size,
            speedX: speedX,
            speedY: speedY,
            amplitudeX: amplitudeX,
            amplitudeY: amplitudeY,
            phaseX: phaseX,
            phaseY: phaseY,
            basePosition: basePosition,
          );
        });

        // Извлекаем акцентный цвет для элементов управления
        final accentColor = palette?.dominantColor?.color ?? context.dynamicPrimaryColor;

        setState(() {
          _currentGradient = paletteService.createGradientFromPalette(palette);
          _floatingCircles = circles;
          _trackAccentColor = accentColor;
        });
      }
    } catch (e) {
      // В случае ошибки используем дефолтный градиент и пустые кружки
      if (mounted) {
        setState(() {
          _currentGradient = null;
          _floatingCircles = [];
        });
      }
      debugPrint('Failed to update gradient for track: $e');
    }
  }

  /// Комбинированный стрим для медиа-элемента, позиции и состояния воспроизведения
  Stream<_MediaState> get _mediaStateStream {
    final handler = AudioServiceManager.getHandler();

    Stream<MediaItem?> mediaItemStream;
    if (handler != null) {
      final initialValue = handler.mediaItem.valueOrNull;
      if (kDebugMode) {
        debugPrint('FullScreenPlayer: Using handler.mediaItem, initial value: ${initialValue?.title}');
      }
      mediaItemStream = handler.mediaItem.startWith(initialValue);
    } else {
      if (kDebugMode) {
        debugPrint('FullScreenPlayer: Using fallback stream (null)');
      }
      mediaItemStream = Stream.value(null);
    }

    final positionStream = AudioService.position.startWith(Duration.zero);

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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    // Адаптивные размеры
    final albumArtSize = isSmallScreen ? 200.0 : 280.0;
    final lyricsHeight = isSmallScreen ? 200.0 : 280.0;
    final titleFontSize = isSmallScreen ? 24.0 : 28.0;
    final artistFontSize = isSmallScreen ? 16.0 : 18.0;
    final spacingAfterAlbum = isSmallScreen ? 20.0 : 40.0;
    final spacingAfterSeek = isSmallScreen ? 12.0 : 24.0;
    final bottomSpacing = isSmallScreen ? 20.0 : 60.0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: BlocListener<QueueBloc, QueueState>(
        listener: (context, queueState) {
          // Очередь синхронизируется автоматически через MediaPlayerService
        },
        child: StreamBuilder<_MediaState>(
          stream: _mediaStateStream,
          builder: (context, snapshot) {
            final mediaState = snapshot.data;
            final track = mediaState?.track;

            if (track == null) {
              return const _LoadingView();
            }

            // Обновляем градиент только при смене трека
            final coverUrl = track.coverPath != null
                ? ImageUtils.getCompleteImageUrl(track.coverPath!)
                : null;
            if (coverUrl != null && coverUrl != _currentTrackCoverUrl && mounted) {
              _currentTrackCoverUrl = coverUrl;
              _updateGradientForTrack(coverUrl, track);
            }

            // Загружаем лирику при смене трека
            if (track.id != _currentTrackId && mounted) {
              _currentTrackId = track.id;
              _loadLyrics(track.id);
            }

            return Stack(
              fit: StackFit.expand,
              children: [
                // Фоновый градиент
                _buildBackground(track),

                // Контент
                SafeArea(
                  child: _LyricsModeInherited(
                    isLyricsModeNotifier: _isLyricsModeNotifier,
                    child: Column(
                    children: [
                      // Кнопка закрытия
                      Align(
                        alignment: Alignment.topLeft,
                        child: AnimatedBuilder(
                          animation: _animationController,
                          builder: (context, child) => Opacity(
                            opacity: _fadeAnimation.value,
                            child: Transform.translate(
                              offset: Offset(0, _slideUpAnimation.value),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.arrow_back, size: 28),
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Обложка альбома или полноэкранная лирика с MD3 анимацией перехода
                      ValueListenableBuilder<bool>(
                        valueListenable: _isLyricsModeNotifier,
                        builder: (context, isLyricsMode, child) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 600),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (Widget child, Animation<double> animation) {
                              // MD3 стиль: комбинация scale, fade и subtle rotation
                              final scaleAnimation = Tween<double>(
                                begin: 0.85,
                                end: 1.0,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                              ));

                              final fadeAnimation = Tween<double>(
                                begin: 0.0,
                                end: 1.0,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOut,
                              ));

                              final rotateAnimation = Tween<double>(
                                begin: 0.02,
                                end: 0.0,
                              ).animate(CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ));

                              return FadeTransition(
                                opacity: fadeAnimation,
                                child: ScaleTransition(
                                  scale: scaleAnimation,
                                  child: RotationTransition(
                                    turns: rotateAnimation,
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: isLyricsMode && _lyricsData?.hasSyncedLyrics == true
                              ? SizedBox(
                                  key: const ValueKey('lyrics_mode'),
                                  height: lyricsHeight,
                                  width: double.infinity,
                                  child: _LyricsDisplay(
                                    lyricsData: _lyricsData!,
                                    currentPosition: mediaState!.position,
                                    accentColor: Colors.white, // Always white
                                  ),
                                )
                              : SizedBox(
                                  key: const ValueKey('album_mode'),
                                  height: albumArtSize,
                                  width: double.infinity,
                                  child: Center(
                                    child: Container(
                                      width: albumArtSize,
                                      height: albumArtSize,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Hero(
                                        tag: 'album_art_${track.id}',
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: CachedNetworkImage(
                                            imageUrl: ImageUtils.getCompleteImageUrl(track.coverPath) ?? '',
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                                              child: CircularProgressIndicator(
                                                color: context.dynamicPrimaryColor,
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Container(
                                              color: context.dynamicPrimaryColor.withValues(alpha: 0.2),
                                              child: Icon(
                                                Icons.music_note,
                                                color: context.dynamicPrimaryColor,
                                                size: isSmallScreen ? 50 : 80,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          );
                        },
                      ),

                      SizedBox(height: spacingAfterAlbum),

                      // Информация о треке (всегда видна)
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) => Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, _slideUpAnimation.value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Column(
                                children: [
                                  // Название трека
                                  Text(
                                    track.title,
                                    style: AppTextStyles.h1.copyWith(
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  // Исполнитель
                                  Text(
                                    track.artist,
                                    style: AppTextStyles.bodySecondary.copyWith(
                                      fontSize: artistFontSize,
                                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Seek полоса
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) => Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, _slideUpAnimation.value),
                            child: _SeekBar(
                              mediaState: mediaState!,
                              onSeek: _handleSeek,
                              trackAccentColor: _trackAccentColor,
                              lyricsData: _lyricsData,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: spacingAfterSeek),

                      // Кнопки управления
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) => Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.translate(
                            offset: Offset(0, _slideUpAnimation.value),
                            child: _ControlButtons(
                              mediaState: mediaState!,
                              onPlayPause: _handlePlayPause,
                              onNext: () => _handleNext(context),
                              onPrevious: () => _handlePrevious(context),
                              onLike: () => _handleLike(context, track),
                              onLyricsToggle: _toggleLyricsMode,
                              trackAccentColor: _trackAccentColor,
                              lyricsData: _lyricsData,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: bottomSpacing),
                    ],
                  ),
                ),
            )],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackground(Track track) {
    return AnimatedBuilder(
      animation: _floatingAnimationController,
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Размытая обложка альбома как фон
            CachedNetworkImage(
              imageUrl: ImageUtils.getCompleteImageUrl(track.coverPath) ?? '',
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Theme.of(context).colorScheme.surface,
              ),
              errorWidget: (context, url, error) => Container(
                color: Theme.of(context).colorScheme.surface,
              ),
            ),

            // Сильная размытость обложки
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
              child: Container(
                color: Colors.transparent,
              ),
            ),

            // Базовый фон для затемнения
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                    Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),

            // Динамические плавающие градиентные формы (поверх обложки)
            if (_currentGradient != null) ..._floatingCircles.map((circle) {
              final time = _floatingAnimationController.value * 2 * pi;
              final xOffset = sin(time * circle.speedX + circle.phaseX) * circle.amplitudeX;
              final yOffset = cos(time * circle.speedY + circle.phaseY) * circle.amplitudeY;

              return Positioned(
                left: circle.basePosition.dx + xOffset,
                top: circle.basePosition.dy + yOffset,
                child: Container(
                  width: circle.size,
                  height: circle.size,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _currentGradient!.colors.map((color) =>
                        color.withValues(alpha: 0.08)).toList(),
                    ),
                    borderRadius: BorderRadius.circular(circle.size / 2),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// Виджет загрузки
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Seek полоса с прогрессом и временем
class _SeekBar extends StatefulWidget {
  final _MediaState mediaState;
  final Function(double, Duration) onSeek;
  final Color? trackAccentColor;
  final LyricsData? lyricsData;

  const _SeekBar({
    required this.mediaState,
    required this.onSeek,
    this.trackAccentColor,
    this.lyricsData,
  });

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> with TickerProviderStateMixin {
  late AnimationController _waveAnimationController;
  late Animation<double> _phaseAnimation;

  @override
  void initState() {
    super.initState();

    // Анимация волны для более живого вида
    _waveAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Период анимации волны
    );

    // Создаем непрерывную фазу волны - каждый цикл дает полный оборот
    _phaseAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi, // Полный цикл волны за один период анимации
    ).animate(CurvedAnimation(
      parent: _waveAnimationController,
      curve: Curves.linear,
    ));

  // Запускаем непрерывную анимацию волны в одном направлении
  _waveAnimationController.repeat();
  }

  @override
  void didUpdateWidget(_SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaState.playing != widget.mediaState.playing) {
      if (widget.mediaState.playing) {
        if (!_waveAnimationController.isAnimating) {
          _waveAnimationController.repeat();
        }
      } else {
        _waveAnimationController.stop();
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _waveAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.mediaState.mediaItem?.duration ?? Duration.zero;
    final progress = widget.mediaState.progress.clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Material Design 3 Linear Progress Indicator с seek функциональностью
          GestureDetector(
            onTapDown: (details) {
              if (duration.inSeconds == 0) return;

              // Вычисляем прогресс на основе позиции касания
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final localPosition = box.globalToLocal(details.globalPosition);
                final progressFromTap = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
                widget.onSeek(progressFromTap, duration);
              }
            },
            onPanUpdate: (details) {
              if (duration.inSeconds == 0) return;

              // Аналогично для drag
              final box = context.findRenderObject() as RenderBox?;
              if (box != null) {
                final localPosition = box.globalToLocal(details.globalPosition);
                final progressFromTap = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
                widget.onSeek(progressFromTap, duration);
              }
            },
            child: Container(
              height: 48, // Высота для удобного касания
              alignment: Alignment.center,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Волнистый прогресс бар
                  AnimatedBuilder(
                    animation: _waveAnimationController,
                    builder: (context, child) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.0),
                        child: LinearProgressIndicatorM3E(
                          value: progress,
                          activeColor: widget.trackAccentColor ?? context.dynamicPrimaryColor,
                          phase: _phaseAnimation.value,
                          inset: 16,
                        ),
                      );
                    },
                  ),

                ],
              ),
            ),
            ),


          const SizedBox(height: 24), // Фиксированное расстояние

          // Область времени + мини-лирики
          SizedBox(
            height: 40, // Увеличенная высота для 2 строк мини-лирики
            child: Stack(
              children: [
                // Время (базовый слой)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatDuration(widget.mediaState.position),
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      _formatDuration(duration),
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),

                // Мини-лирика (если доступна) - накладывается поверх времени без перестройки
                if (widget.lyricsData?.hasSyncedLyrics == true)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250), // Ограничение ширины для более раннего переноса
                        child: _MiniLyricsDisplay(
                          lyricsData: widget.lyricsData!,
                          currentPosition: widget.mediaState.position,
                          accentColor: Colors.white, // Always white
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Кнопки управления воспроизведением
class _ControlButtons extends StatelessWidget {
  final _MediaState mediaState;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onLike;
  final VoidCallback onLyricsToggle;
  final Color? trackAccentColor;
  final LyricsData? lyricsData;

  const _ControlButtons({
    required this.mediaState,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onLike,
    required this.onLyricsToggle,
    this.trackAccentColor,
    this.lyricsData,
  });

  @override
  Widget build(BuildContext context) {
    final inherited = _LyricsModeInherited.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: inherited!.isLyricsModeNotifier,
      builder: (context, isLyricsMode, child) {
        final track = mediaState.track!;

        return Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Текст песни
                IconButton(
                  onPressed: lyricsData?.hasAnyLyrics == true ? onLyricsToggle : null,
                  icon: Icon(
                    Icons.subtitles,
                    color: lyricsData?.hasAnyLyrics == true
                        ? (isLyricsMode ? Colors.white : Colors.white.withValues(alpha: 0.7))
                        : Colors.white.withValues(alpha: 0.3),
                    size: 28,
                  ),
                ),

                // Предыдущий трек
                IconButton(
                  onPressed: onPrevious,
                  icon: Icon(
                    Icons.skip_previous,
                    color: Colors.white,
                    size: 36,
                  ),
                ),

                // Play/Pause
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: mediaState.isBuffering ? null : onPlayPause,
                    icon: mediaState.isBuffering
                        ? SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            mediaState.playing ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 40,
                          ),
                  ),
                ),

                // Следующий трек
                IconButton(
                  onPressed: onNext,
                  icon: Icon(
                    Icons.skip_next,
                    color: Colors.white,
                    size: 36,
                  ),
                ),

                // Лайк
                _AnimatedLikeButton(
                  isLiked: track.isLiked,
                  onTap: onLike,
                  trackAccentColor: Colors.white, // Always white
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Полноэкранный режим отображения лирики в стиле Spotify с анимациями
class _LyricsDisplay extends StatefulWidget {
  final LyricsData lyricsData;
  final Duration currentPosition;
  final Color accentColor;

  const _LyricsDisplay({
    required this.lyricsData,
    required this.currentPosition,
    required this.accentColor,
  });

  @override
  State<_LyricsDisplay> createState() => _LyricsDisplayState();
}

class _LyricsDisplayState extends State<_LyricsDisplay>
    with TickerProviderStateMixin {
  late AnimationController _transitionController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String? _previousText;
  String? _currentText;
  String? _nextText;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeInOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeOutBack,
      ),
    );

    _updateTexts();
  }

  @override
  void didUpdateWidget(_LyricsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition ||
        oldWidget.lyricsData != widget.lyricsData) {
      final oldCurrentLine = widget.lyricsData.getCurrentLine(oldWidget.currentPosition.inMilliseconds);
      final newCurrentLine = widget.lyricsData.getCurrentLine(widget.currentPosition.inMilliseconds);

      // Анимируем только при смене строки
      if (oldCurrentLine?.lineId != newCurrentLine?.lineId) {
        _transitionController.forward(from: 0.0);
      }
      _updateTexts();
    }
  }

  void _updateTexts() {
    final currentTimeMs = widget.currentPosition.inMilliseconds;
    final currentLine = widget.lyricsData.getCurrentLine(currentTimeMs);
    final previousLine = widget.lyricsData.getPreviousLine(currentTimeMs);
    final nextLine = widget.lyricsData.getNextLine(currentTimeMs);

    _previousText = previousLine?.text;
    _currentText = currentLine?.text;
    _nextText = nextLine?.text;
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    // Адаптивные размеры шрифтов для лирики
    final previousFontSize = isSmallScreen ? 14.0 : 16.0;
    final currentFontSize = isSmallScreen ? 20.0 : 24.0;
    final nextFontSize = isSmallScreen ? 14.0 : 16.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedBuilder(
        animation: _transitionController,
        builder: (context, child) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Предыдущая строка (размытая и маленькая) - с анимацией ухода вверх
              if (_previousText != null && _previousText!.isNotEmpty)
                Transform.translate(
                  offset: Offset(0, -_slideAnimation.value * 0.5),
                  child: Opacity(
                    opacity: (0.8 * _fadeAnimation.value).clamp(0.0, 1.0),
                    child: _LyricsLine(
                      text: _previousText!,
                      fontSize: previousFontSize,
                      opacity: 0.8,
                      blur: 0.0, // Убираем размытие полностью
                      color: widget.accentColor.withValues(alpha: 0.6), // Делаем цвет более тусклым
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Текущая строка (большая и яркая) - с анимацией появления
              if (_currentText != null && _currentText!.isNotEmpty)
                Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value,
                    child: _LyricsLine(
                      text: _currentText!,
                      fontSize: currentFontSize,
                      opacity: 1.0,
                      blur: 0.0,
                      color: widget.accentColor,
                      isCurrent: true,
                    ),
                  ),
                ),

              const SizedBox(height: 24),

              // Следующая строка (постепенно проявляется)
              if (_nextText != null && _nextText!.isNotEmpty)
                Transform.translate(
                  offset: Offset(0, _slideAnimation.value * 0.3),
                  child: Opacity(
                    opacity: 0.4 * _fadeAnimation.value,
                    child: _LyricsLine(
                      text: _nextText!,
                      fontSize: nextFontSize,
                      opacity: 0.5,
                      blur: 1.0 + (1.0 - _fadeAnimation.value) * 1.0,
                      color: widget.accentColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Одна строка лирики с анимацией
class _LyricsLine extends StatelessWidget {
  final String text;
  final double fontSize;
  final double opacity;
  final double blur;
  final Color color;
  final bool isCurrent;

  const _LyricsLine({
    required this.text,
    required this.fontSize,
    required this.opacity,
    required this.blur,
    required this.color,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget textWidget = Text(
      text,
      style: AppTextStyles.h1.copyWith(
        fontSize: fontSize,
        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
        color: color.withValues(alpha: opacity),
        height: 1.2,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.3),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );

    // Применяем размытие для неактивных строк
    if (blur > 0) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: textWidget,
      );
    }

    return textWidget;
  }
}

/// Мини-режим отображения лирики с анимациями переходов
class _MiniLyricsDisplay extends StatefulWidget {
  final LyricsData lyricsData;
  final Duration currentPosition;
  final Color accentColor;

  const _MiniLyricsDisplay({
    required this.lyricsData,
    required this.currentPosition,
    required this.accentColor,
  });

  @override
  State<_MiniLyricsDisplay> createState() => _MiniLyricsDisplayState();
}

class _MiniLyricsDisplayState extends State<_MiniLyricsDisplay>
    with TickerProviderStateMixin {
  late AnimationController _transitionController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  String? _currentText;

  @override
  void initState() {
    super.initState();
    _transitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _transitionController,
        curve: Curves.easeOutCubic,
      ),
    );

    _updateText();
  }

  @override
  void didUpdateWidget(_MiniLyricsDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPosition != widget.currentPosition ||
        oldWidget.lyricsData != widget.lyricsData) {
      final oldLine = widget.lyricsData.getCurrentLine(oldWidget.currentPosition.inMilliseconds);
      final newLine = widget.lyricsData.getCurrentLine(widget.currentPosition.inMilliseconds);

      // Анимируем только при смене строки
      if (oldLine?.lineId != newLine?.lineId) {
        _transitionController.forward(from: 0.0);
      }
      _updateText();
    }
  }

  void _updateText() {
    final currentTimeMs = widget.currentPosition.inMilliseconds;
    final currentLine = widget.lyricsData.getCurrentLine(currentTimeMs);
    _currentText = currentLine?.text;
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inherited = _LyricsModeInherited.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: inherited!.isLyricsModeNotifier,
      builder: (context, isLyricsMode, child) {
        if (isLyricsMode) {
          return const SizedBox.shrink();
        }

        if (_currentText == null || _currentText!.isEmpty) {
          return const SizedBox.shrink();
        }

        return AnimatedBuilder(
          animation: _transitionController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    _currentText!,
                    style: AppTextStyles.bodySecondary.copyWith(
                      fontSize: 14,
                      color: widget.accentColor.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          offset: const Offset(0, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Анимированная кнопка лайка
class _AnimatedLikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback? onTap;
  final Color? trackAccentColor;

  const _AnimatedLikeButton({
    required this.isLiked,
    this.onTap,
    this.trackAccentColor,
  });

  @override
  State<_AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<_AnimatedLikeButton>
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

    _colorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

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
  void didUpdateWidget(_AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);

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

    HapticFeedback.lightImpact();

    final willBeLiked = !widget.isLiked;
    if (willBeLiked) {
      _animationController.forward(from: 0.0);
    } else {
      _animationController.reverse(from: 1.0);
    }

    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final likedColor = widget.trackAccentColor ?? context.dynamicPrimaryColor;
            final unlikedColor = AppColors.textSecondary;
            final animatedColor = Color.lerp(
              unlikedColor,
              likedColor,
              _colorAnimation.value,
            ) ?? unlikedColor;

            final icon = _colorAnimation.value > 0.5
                ? Icons.favorite
                : Icons.favorite_border;

            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Icon(
                icon,
                size: 28,
                color: animatedColor,
              ),
            );
          },
        ),
      ),
    );
  }
}
