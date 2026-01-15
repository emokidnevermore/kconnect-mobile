/// Компонент редактирования имени пользователя (username)
///
/// Предоставляет текстовое поле для ввода и редактирования username с префиксом @.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/services/storage_service.dart';

/// Виджет секции редактирования имени пользователя
class UsernameEditSection extends StatelessWidget {
  final TextEditingController controller;

  const UsernameEditSection({
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
                  'Имя пользователя',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLength: 16,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')), // Запрещаем пробелы
                  ],
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
                    final hasSpaces = controller.text.contains(' ');
                    return Text(
                      '$currentLength/$maxLength',
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 12,
                        color: currentLength == 0
                            ? Theme.of(context).colorScheme.error
                            : hasSpaces
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                  decoration: InputDecoration(
                    hintText: 'username',
                    prefixText: '@',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    errorText: _getErrorText(controller.text),
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

  String? _getErrorText(String text) {
    if (text.trim().isEmpty) {
      return 'Имя пользователя не может быть пустым';
    }
    if (text.contains(' ')) {
      return 'Имя пользователя не может содержать пробелы';
    }
    return null;
  }
}
