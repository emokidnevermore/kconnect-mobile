/// Виджет shimmer-эффекта для постов
///
/// Отображает анимированный placeholder во время загрузки постов.
/// Имитирует структуру реального поста с аватаром, текстом и статистикой.
library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Виджет для отображения shimmer-эффекта загрузки поста
///
/// Создает анимированные placeholder'ы, имитирующие структуру поста:
/// аватар пользователя, имя, контент и статистику взаимодействий.
class PostShimmer extends StatelessWidget {
  const PostShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      period: const Duration(milliseconds: 1200),
      child: Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Хедер: аватар + имя
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: 100,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 12,
                      width: 80,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Контент
          Container(
            height: 60,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          const SizedBox(height: 8),
          // Статистика
          Row(
            children: [
              Container(
                height: 20,
                width: 40,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 30,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 20,
                width: 40,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
        ],
      ),
    )
    );
  }
}
