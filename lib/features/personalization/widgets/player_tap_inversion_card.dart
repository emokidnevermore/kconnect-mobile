/// Карточка настройки инверсии поведения тапа плеера
library;

import 'package:flutter/material.dart';
import '../../../../theme/app_text_styles.dart';
import 'personalization_card.dart';

/// Карточка для переключения инверсии поведения тапа плеера
class PlayerTapInversionCard extends StatelessWidget {
  final bool invertPlayerTapBehavior;
  final ValueChanged<bool> onChanged;

  const PlayerTapInversionCard({
    super.key,
    required this.invertPlayerTapBehavior,
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
                  'Инвертировать поведение плеера',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Меняет назначение короткого и долгого нажатия на мини-плеере: короткое нажатие откроет полноэкранный плеер, а долгое - переключит режим мини-плеера',
                  style: AppTextStyles.bodySecondary.copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: invertPlayerTapBehavior,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
