import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/widgets/profile_accent_color_provider.dart';
import '../../../services/cache/audio_preload_service.dart';
import '../../music/domain/models/track.dart';
import '../../music/domain/repositories/audio_repository.dart';
import '../../music/presentation/blocs/music_bloc.dart';
import '../../music/presentation/blocs/music_event.dart';
import '../../../injection.dart';

/// Утилита для форматирования длительности трека в формат MM:SS
String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

/// Компонент для отображения музыкальных треков в постах
///
/// Показывает список прикрепленных музыкальных треков с обложками,
/// названиями, исполнителями и кнопками лайка.
/// Треки кликабельны для воспроизведения.
/// Интегрируется с системой воспроизведения музыки и MusicBloc для лайков.
class PostMusic extends StatelessWidget {
  final List<Track> tracks;

  const PostMusic({
    super.key,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: tracks.map((track) => _TrackRow(key: ValueKey(track.id), track: track)).toList(),
      ),
    );
  }
}

/// Виджет для отображения отдельного трека с анимацией лайка
class _TrackRow extends StatefulWidget {
  final Track track;

  const _TrackRow({
    super.key,
    required this.track,
  });

  @override
  State<_TrackRow> createState() => _TrackRowState();
}

class _TrackRowState extends State<_TrackRow> with SingleTickerProviderStateMixin {
  late AnimationController _likeAnimationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _colorAnimation;
  final AudioPreloadService _preloadService = AudioPreloadService.instance;
  bool _hasPreloaded = false;

  @override
  void initState() {
    super.initState();
    
    // Предзагружаем трек при создании виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasPreloaded) {
        _preloadService.preloadTrack(
          widget.track,
          priority: PreloadPriority.visible,
        );
        _hasPreloaded = true;
      }
    });
    
    // Initialize animation controller based on current liked state
    final isLiked = widget.track.isLiked;
    
    _likeAnimationController = AnimationController(
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
    ]).animate(_likeAnimationController);

    _colorAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _likeAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Set initial state
    if (isLiked) {
      _likeAnimationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _likeAnimationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_TrackRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update animation state if track liked status changed externally
    if (widget.track.isLiked != oldWidget.track.isLiked) {
      if (widget.track.isLiked) {
        _likeAnimationController.forward();
      } else {
        _likeAnimationController.reverse();
      }
    }
  }

  void _playTrack(BuildContext context, Track track) {
    final audioRepository = locator<AudioRepository>();
    audioRepository.playTrack(track).catchError((e) {
      debugPrint('PostMusic: Error playing track: $e');
    });
  }

  void _onLikePressed(BuildContext context, Track track) {
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Trigger animation immediately for responsive UI
    final willBeLiked = !widget.track.isLiked;
    if (willBeLiked) {
      _likeAnimationController.forward(from: 0.0);
    } else {
      _likeAnimationController.reverse(from: 1.0);
    }
    
    // Send event to MusicBloc
    try {
      context.read<MusicBloc>().add(MusicTrackLiked(track.id, track));
    } catch (e) {
      debugPrint('PostMusic: Error liking track: $e');
      // Revert animation on error
      if (willBeLiked) {
        _likeAnimationController.reverse();
      } else {
        _likeAnimationController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final durationText = _formatDuration(widget.track.durationMs ~/ 1000);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () => _playTrack(context, widget.track),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Row(
            children: [
              // Обложка альбома
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: ImageUtils.buildAlbumArt(
                    ImageUtils.getCompleteImageUrl(widget.track.coverPath),
                    context,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Информация о треке
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Название трека
                    Text(
                      widget.track.title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Исполнитель
                    Text(
                      widget.track.artist,
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Длительность
              Text(
                durationText,
                style: AppTextStyles.bodySecondary.copyWith(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              // Кнопка лайка с анимацией
              GestureDetector(
                onTap: () => _onLikePressed(context, widget.track),
                behavior: HitTestBehavior.opaque,
                child: AnimatedBuilder(
                  animation: _likeAnimationController,
                  builder: (context, child) {
                    // Interpolate color between unliked and liked state
                    final likedColor = context.profileAccentColor;
                    final unlikedColor = colorScheme.onSurfaceVariant;
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
                        size: 20,
                        color: animatedColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
