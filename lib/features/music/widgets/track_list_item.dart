/// Элемент списка треков для вертикального отображения
///
/// Отображает трек в формате списка с обложкой, названием,
/// исполнителем, длительностью и кнопкой лайка.
/// Используется в результатах поиска и истории прослушиваний.
library;

import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../services/cache/audio_preload_service.dart';
import '../domain/models/track.dart';

/// Виджет элемента списка треков
///
/// Показывает информацию о треке в компактном вертикальном формате.
/// Поддерживает лайки и навигацию к воспроизведению.
class TrackListItem extends StatefulWidget {
  final Track track;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final bool showLikeButton;

  const TrackListItem({
    super.key,
    required this.track,
    this.onTap,
    this.onLike,
    this.showLikeButton = true,
  });

  @override
  State<TrackListItem> createState() => _TrackListItemState();
}

class _TrackListItemState extends State<TrackListItem> with AutomaticKeepAliveClientMixin {
  final AudioPreloadService _preloadService = AudioPreloadService.instance;
  bool _hasPreloaded = false;

  @override
  bool get wantKeepAlive => true;

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
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Обложка
            ImageUtils.buildAlbumArt(
              ImageUtils.getCompleteImageUrl(widget.track.coverPath),
              context,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
            const SizedBox(width: 12),
            // Информация о треке
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Название
                  Text(
                    widget.track.title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Artist
                  Text(
                    widget.track.artist,
                    style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Duration
            Text(
              _formatDuration(widget.track.durationMs ~/ 1000),
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
            ),
            // Кнопка лайка
            if (widget.showLikeButton) ...[
              const SizedBox(width: 12),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: widget.onLike,
                icon: Icon(
                  widget.track.isLiked ? Icons.favorite : Icons.favorite_border,
                  size: 20,
                  color: widget.track.isLiked ? context.dynamicPrimaryColor : AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(int duration) {
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
