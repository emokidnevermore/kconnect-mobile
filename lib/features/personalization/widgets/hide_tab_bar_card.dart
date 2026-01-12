/// Карточка настройки скрытия таб-бара
library;

import 'package:flutter/material.dart';
import '../../../../theme/app_text_styles.dart';
import 'personalization_card.dart';

/// Карточка для переключения скрытия таб-бара
class HideTabBarCard extends StatelessWidget {
  final bool hideTabBar;
  final ValueChanged<bool> onChanged;

  const HideTabBarCard({
    super.key,
    required this.hideTabBar,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PersonalizationCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Скрыть таб бар',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Скрывает визуально таб бар, оставляя только кнопку музыки и динамическую кнопку',
                  style: AppTextStyles.bodySecondary.copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: hideTabBar,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
