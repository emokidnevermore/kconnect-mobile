/// Карточка категории кэша
///
/// Отображает информацию о категории кэша с возможностью выбора для очистки.
library;

import 'package:flutter/material.dart';
import '../../../services/cache/cache_category.dart';
import '../../../core/utils/cache_size_calculator.dart';
import '../../../services/storage_service.dart';

/// Карточка категории кэша
class CacheCategoryCard extends StatelessWidget {
  /// Категория кэша
  final CacheCategory category;

  /// Размер кэша в байтах
  final int cacheSize;

  /// Выбрана ли категория
  final bool isSelected;

  /// Callback при изменении выбора
  final ValueChanged<bool> onSelectionChanged;

  const CacheCategoryCard({
    super.key,
    required this.category,
    required this.cacheSize,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, backgroundPath, child) {
        final colorScheme = Theme.of(context).colorScheme;
        final categoryColor = category.getColor(colorScheme);
        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
        final cardColor = hasBackground
            ? colorScheme.surface.withValues(alpha: 0.7)
            : colorScheme.surfaceContainerLow;

        return Card(
          margin: EdgeInsets.zero,
          color: cardColor,
          child: InkWell(
            onTap: () => onSelectionChanged(!isSelected),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Иконка категории
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      category.icon,
                      color: categoryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Информация о категории
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CacheSizeCalculator.formatBytes(cacheSize),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: categoryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Чекбокс
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (value) => onSelectionChanged(value ?? false),
                      activeColor: categoryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
