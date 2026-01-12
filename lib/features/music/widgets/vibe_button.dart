/// Виджет кнопки для генерации персонализированного плейлиста "Vibe"
///
/// Отображает привлекательную кнопку с градиентом для запуска
/// сервиса генерации музыки на основе предпочтений пользователя.
/// Поддерживает состояние загрузки и персонализированные цвета.
library;

import 'package:flutter/material.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/utils/theme_extensions.dart';

/// Виджет кнопки Vibe
class VibeButton extends StatelessWidget {
  final VoidCallback onGenerateVibe;
  final bool isLoading;

  const VibeButton({
    super.key,
    required this.onGenerateVibe,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: InkWell(
        onTap: isLoading ? null : onGenerateVibe,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.dynamicGradientStart, context.dynamicGradientEnd],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Icon section
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 16),
                child: Icon(
                  Icons.auto_awesome,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              // Text section
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Мой вайб',
                      style: AppTextStyles.h2.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    Text(
                      'Сервис сам подберёт треки для тебя',
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.9),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Arrow section
              Padding(
                padding: const EdgeInsets.all(24),
                child: isLoading
                    ? CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onPrimary,
                        strokeWidth: 2,
                      )
                    : Icon(
                        Icons.chevron_right,
                        size: 24,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
