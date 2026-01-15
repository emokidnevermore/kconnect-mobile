/// Компонент редактирования описания профиля
///
/// Предоставляет многострочное текстовое поле для ввода и редактирования описания профиля.
library;

import 'package:flutter/material.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/services/storage_service.dart';

/// Виджет секции редактирования описания
class DescriptionEditSection extends StatelessWidget {
  final TextEditingController controller;

  const DescriptionEditSection({
    super.key,
    required this.controller,
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

        return Card(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Описание',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: null, // Разрешить динамическое расширение
                  minLines: 4, // Минимальная высота - 4 строки
                  maxLength: 200,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                    return Text(
                      '$currentLength/$maxLength',
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'Расскажите о себе...',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
