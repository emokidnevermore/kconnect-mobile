/// Компонент секции управления фоном приложения
library;

import 'package:flutter/material.dart';
import 'dart:io';
import '../../../../theme/app_text_styles.dart';
import 'personalization_card.dart';

/// Секция управления фоном приложения
class BackgroundSection extends StatelessWidget {
  final String? backgroundPath;
  final String? backgroundType;
  final String? backgroundName;
  final int? backgroundSize;
  final String? backgroundThumbnailPath;
  final VoidCallback onPickBackground;
  final VoidCallback onRemoveBackground;

  const BackgroundSection({
    super.key,
    this.backgroundPath,
    this.backgroundType,
    this.backgroundName,
    this.backgroundSize,
    this.backgroundThumbnailPath,
    required this.onPickBackground,
    required this.onRemoveBackground,
  });

  @override
  Widget build(BuildContext context) {
    return PersonalizationCard(
      child: Row(
        children: [
          // Предпоказ фона (кликабельный)
          InkWell(
            onTap: onPickBackground,
            borderRadius: BorderRadius.circular(8),
            child: _BackgroundPreview(
              backgroundPath: backgroundPath,
              backgroundType: backgroundType,
              backgroundThumbnailPath: backgroundThumbnailPath,
            ),
          ),
          const SizedBox(width: 12),
          // Метаданные (название и размер)
          Expanded(
            child: backgroundPath != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        backgroundName ?? 'Фон',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatFileSize(backgroundSize ?? 0),
                        style: AppTextStyles.bodySecondary.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          // Кнопка удаления
          if (backgroundPath != null)
            TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onRemoveBackground,
              child: Text(
                'Удалить',
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Предпоказ фона
class _BackgroundPreview extends StatelessWidget {
  final String? backgroundPath;
  final String? backgroundType;
  final String? backgroundThumbnailPath;

  const _BackgroundPreview({
    this.backgroundPath,
    this.backgroundType,
    this.backgroundThumbnailPath,
  });

  @override
  Widget build(BuildContext context) {
    if (backgroundPath == null) {
      return Container(
        width: 120,
        height: 80,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.photo,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          size: 32,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: backgroundType == 'video'
          ? Container(
              width: 120,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Stack(
                children: [
                  // Показываем thumbnail если есть
                  if (backgroundThumbnailPath != null && File(backgroundThumbnailPath!).existsSync())
                    Positioned.fill(
                      child: Image.file(
                        File(backgroundThumbnailPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
                    )
                  else if (backgroundPath != null && File(backgroundPath!).existsSync())
                    Positioned.fill(
                      child: Image.file(
                        File(backgroundPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  // Иконка видео поверх
                  Center(
                    child: Icon(
                      Icons.videocam,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                ],
              ),
            )
          : Image.file(
              File(backgroundPath!),
              width: 120,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 120,
                  height: 80,
                  color: Theme.of(context).colorScheme.surface,
                  child: Icon(
                    Icons.warning,
                    color: Theme.of(context).colorScheme.error,
                  ),
                );
              },
            ),
    );
  }
}
