/// Карточка трека для отображения в горизонтальных списках
///
/// Отображает обложку трека, название, исполнителя, жанр и статус верификации.
/// Поддерживает различные действия: воспроизведение, лайк, навигация.
/// Используется в секциях музыки для показа треков.
library;

import 'package:flutter/material.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/theme_extensions.dart';
import '../domain/models/track.dart';

/// Виджет карточки трека с обложкой и информацией
///
/// Показывает трек в компактном формате с обложкой,
/// названием, исполнителем и дополнительными элементами (лайк, верификация).
class TrackCard extends StatelessWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onLike;

  const TrackCard({
    super.key,
    required this.track,
    this.onTap,
    this.onPlay,
    this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final title = track.title;
    final artist = track.artist;
    final albumArt = track.coverPath;
    final genre = track.genre?.trim();
    final verified = track.verified;

    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(right: 12),
        clipBehavior: Clip.antiAlias,
        color: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          width: 160,
          height: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Album art with overlay
              Stack(
                children: [
                  ImageUtils.buildAlbumArt(
                    ImageUtils.getCompleteImageUrl(albumArt),
                    context,
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                  // Genre badge top-left
                  if (genre != null && genre.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: FilterChip(
                        label: Text(
                          genre,
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontSize: 10,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        onSelected: (_) {},
                      ),
                    ),

                  // Verified badge top-right
                  if (verified)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Badge(
                        backgroundColor: context.dynamicPrimaryColor,
                        child: Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),

                ],
              ),
              // Title
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Artist (single line to save space)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  artist,
                  style: AppTextStyles.bodySecondary.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



}
