/// Навигационные карточки для музыкальных разделов
///
/// Переиспользуемые карточки для навигации по разделам музыки:
/// избранные треки, плейлисты и другие музыкальные функции.
/// Поддерживают разные цвета и иконки для визуального различения.
library;

import 'package:flutter/material.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../services/storage_service.dart';

/// Карточка навигации для музыкальных разделов
///
/// Отображает иконку, заголовок и поддерживает нажатие.
/// Используется для создания навигации по разделам музыки.
class MusicNavigationCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;

  const MusicNavigationCard({
    super.key,
    required this.title,
    this.icon,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
final accentColor = color ?? context.dynamicPrimaryColor;

    return Expanded(
      child: ValueListenableBuilder<String?>(
        valueListenable: StorageService.appBackgroundPathNotifier,
        builder: (context, backgroundPath, child) {
          final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
          final cardColor = hasBackground 
              ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
              : Theme.of(context).colorScheme.surfaceContainerLow;
          
          return Card(
            margin: EdgeInsets.zero,
            color: cardColor,
            child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 24,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
          );
        },
      ),
    );
  }
}

/// Navigation cards row widget for consistent layout
class MusicNavigationCardsRow extends StatelessWidget {
  final MusicNavigationCard leftCard;
  final MusicNavigationCard rightCard;

  const MusicNavigationCardsRow({
    super.key,
    required this.leftCard,
    required this.rightCard,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          leftCard,
          const SizedBox(width: 8),
          rightCard,
        ],
      ),
    );
  }
}
