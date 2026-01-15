/// Карточка настройки режима отображения изображений в сообщениях
library;

import 'package:flutter/material.dart';
import '../../../../theme/app_text_styles.dart';
import 'personalization_card.dart';

/// Карточка для выбора режима отображения изображений в сообщениях
class MessageImageFitCard extends StatelessWidget {
  final BoxFit selectedFit;
  final ValueChanged<BoxFit> onChanged;

  const MessageImageFitCard({
    super.key,
    required this.selectedFit,
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
                  'Изображения в сообщениях',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Выберите, как должны отображаться изображения в сообщениях чата',
                  style: AppTextStyles.bodySecondary.copyWith(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<BoxFit>(
            value: selectedFit,
            onChanged: (BoxFit? newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
            items: BoxFit.values.map<DropdownMenuItem<BoxFit>>((BoxFit fit) {
              return DropdownMenuItem<BoxFit>(
                value: fit,
                child: Text(
                  _getFitDisplayName(fit),
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getFitDisplayName(BoxFit fit) {
    switch (fit) {
      case BoxFit.cover:
        return 'Заполнить';
      case BoxFit.contain:
        return 'Вместить';
      case BoxFit.fill:
        return 'Растянуть';
      case BoxFit.fitWidth:
        return 'По ширине';
      case BoxFit.fitHeight:
        return 'По высоте';
      case BoxFit.none:
        return 'Без масштаба';
      case BoxFit.scaleDown:
        return 'Уменьшить';
    }
  }
}
