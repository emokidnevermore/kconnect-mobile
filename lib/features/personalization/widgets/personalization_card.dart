/// Общий виджет карточки персонализации
///
/// Автоматически обрабатывает наличие фона и применяет соответствующий стиль
library;

import 'package:flutter/material.dart';
import '../../../../services/storage_service.dart';

/// Карточка персонализации с адаптивным фоном
class PersonalizationCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const PersonalizationCard({
    super.key,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, backgroundPath, child) {
        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
        final cardColor = hasBackground 
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
            : Theme.of(context).colorScheme.surfaceContainerLow;
        
        return Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: this.child,
        );
      },
    );
  }
}
