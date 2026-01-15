/// Карточка настройки режима темы (светлая/темная)
library;

import 'package:flutter/material.dart';
import '../../../../theme/app_text_styles.dart';
import 'personalization_card.dart';

/// Карточка для переключения между светлой и темной темой
class ThemeModeCard extends StatelessWidget {
  final bool useLightTheme;
  final ValueChanged<bool> onChanged;

  const ThemeModeCard({
    super.key,
    required this.useLightTheme,
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
                  'Режим темы',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Переключение между светлой и темной темой приложения',
                  style: AppTextStyles.bodySecondary.copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: useLightTheme,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
