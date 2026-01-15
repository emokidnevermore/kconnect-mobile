/// Расширенный плеер для навигационной панели
///
/// Компонент расширенного плеера, который показывает полную
/// информацию о треке и элементы управления
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../core/utils/image_utils.dart';
import '../../services/storage_service.dart';
import '../../core/utils/theme_extensions.dart';
import '../../features/music/domain/models/track.dart';
import '../../features/music/presentation/blocs/music_bloc.dart';
import '../../features/music/presentation/blocs/music_event.dart';
import '../../features/music/presentation/blocs/queue_bloc.dart';
import '../../features/music/presentation/blocs/queue_event.dart';
import '../../services/audio_service_manager.dart';
import 'glass_mode_wrapper.dart';
import '_animated_mini_player_like_button.dart';

/// Расширенный плеер
class ExpandedPlayer extends StatelessWidget {
  /// Состояние медиа
  final ({bool hasTrack, bool playing, double progress, Track? track, bool isBuffering}) mediaState;

  /// Колбэк при нажатии на полноэкранный плеер
  final VoidCallback? onFullScreenTap;

  /// Колбэк при сворачивании плеера
  final VoidCallback? onCollapse;

  const ExpandedPlayer({
    super.key,
    required this.mediaState,
    this.onFullScreenTap,
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    if (!mediaState.hasTrack || mediaState.track == null) {
      return const SizedBox();
    }

    return FutureBuilder<bool>(
      future: StorageService.getInvertPlayerTapBehavior(),
      builder: (context, invertSnapshot) {

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
          child: Container(
            width: MediaQuery.of(context).size.width - 24,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(
                color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Album art positioned at left
                Positioned(
                  left: 3,
                  child: GestureDetector(
                    onTap: onCollapse,
                    child: Hero(
                      tag: 'album_art_${mediaState.track!.id}_button',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: CachedNetworkImage(
                            imageUrl: ImageUtils.getCompleteImageUrl(mediaState.track!.coverPath) ?? '',
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
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Background tap area
                FutureBuilder<bool>(
                  future: StorageService.getInvertPlayerTapBehavior(),
                  builder: (context, snapshot) {
                    final invert = snapshot.data ?? false;
                    return GestureDetector(
                      onTap: invert ? onFullScreenTap : onCollapse,
                      onLongPress: invert ? onCollapse : onFullScreenTap,
                      behavior: HitTestBehavior.translucent,
                      child: Container(
                        color: Colors.transparent,
                      ),
                    );
                  },
                ),

                // Expanded content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Spacer for album art
                      const SizedBox(width: 52),
                      // Track info
                      Expanded(
                        child: GestureDetector(
                          onTap: onCollapse,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                mediaState.track!.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                mediaState.track!.artist,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.1,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Controls
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                            const SizedBox(width: 2),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: mediaState.isBuffering ? null : () => _handlePlayPause(context),
                              icon: _buildPlayAnimatedIcon(context, mediaState.playing, mediaState.isBuffering),
                            ),
                            const SizedBox(width: 2),
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
                            const SizedBox(width: 16),
                            AnimatedMiniPlayerLikeButton(
                              isLiked: mediaState.track!.isLiked,
                              onTap: () => _handleLike(context, mediaState.track!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handlePlayPause(BuildContext context) {
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
