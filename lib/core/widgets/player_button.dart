/// Кнопка плеера для навигационной панели
///
/// Компонент кнопки плеера, который показывает обложку трека
/// или иконку музыки в зависимости от состояния воспроизведения
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../core/utils/image_utils.dart';
import '../../services/storage_service.dart';
import '../../core/utils/theme_extensions.dart';
import '../../features/music/domain/models/track.dart';
import 'glass_mode_wrapper.dart';

/// Кнопка плеера
class PlayerButton extends StatelessWidget {
  /// Размер кнопки
  final double size;

  /// Колбэк при нажатии
  final VoidCallback? onPressed;

  /// Колбэк при долгом нажатии
  final VoidCallback? onLongPress;

  /// Состояние медиа
  final ({bool hasTrack, bool playing, double progress, Track? track, bool isBuffering}) mediaState;

  const PlayerButton({
    super.key,
    this.size = 50.0,
    this.onPressed,
    this.onLongPress,
    required this.mediaState,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: mediaState.hasTrack && mediaState.track != null
          ? _buildAlbumArtButton(context)
          : _buildMusicIconButton(context),
    );
  }

  /// Построить кнопку с обложкой альбома
  Widget _buildAlbumArtButton(BuildContext context) {
    final track = mediaState.track!;

    return FutureBuilder<bool>(
      future: StorageService.getInvertPlayerTapBehavior(),
      builder: (context, invertSnapshot) {
        final invert = invertSnapshot.data ?? false;

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
          child: GestureDetector(
            onTap: invert ? onLongPress : onPressed,
            onLongPress: invert ? onPressed : onLongPress,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Hero(
                  tag: 'album_art_${track.id}_button',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: SizedBox(
                      width: 50,
                      height: 50,
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
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Circular progress indicator around the album art
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    value: mediaState.progress.clamp(0.0, 1.0),
                    strokeWidth: 4,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.dynamicPrimaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Построить кнопку с иконкой музыки
  Widget _buildMusicIconButton(BuildContext context) {
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
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: onPressed,
        icon: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.music_note,
              size: 24,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            if (mediaState.hasTrack)
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  value: mediaState.progress.clamp(0.0, 1.0),
                  strokeWidth: 2,
                  backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(context.dynamicPrimaryColor),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
