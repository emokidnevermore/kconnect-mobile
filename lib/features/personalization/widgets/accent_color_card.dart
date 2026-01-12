/// Карточка настройки акцентного цвета
library;

import 'package:flutter/material.dart';
import '../../../../theme/app_text_styles.dart';
import 'personalization_card.dart';

/// Карточка для переключения использования акцентного цвета профиля
class AccentColorCard extends StatelessWidget {
  final bool useProfileAccentColor;
  final ValueChanged<bool> onChanged;

  const AccentColorCard({
    super.key,
    required this.useProfileAccentColor,
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
                  'Использовать акцентный цвет профиля',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Заменяет акцентный цвет приложения на цвет из вашего профиля',
                  style: AppTextStyles.bodySecondary.copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: useProfileAccentColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
