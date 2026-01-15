/// Компонент редактирования акцентного цвета профиля
///
/// Позволяет пользователю выбрать акцентный цвет профиля из предустановленных вариантов.
library;

import 'package:flutter/material.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/services/storage_service.dart';

/// Виджет секции редактирования акцентного цвета
class AccentColorEditSection extends StatelessWidget {
  final String? selectedProfileColor;
  final VoidCallback onPickAccentColor;

  const AccentColorEditSection({
    super.key,
    required this.selectedProfileColor,
    required this.onPickAccentColor,
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
                  'Акцентный цвет профиля',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: onPickAccentColor,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _getProfileColor(context),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Выбрать цвет',
                            style: AppTextStyles.body,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getProfileColor(BuildContext context) {
    if (selectedProfileColor == null || selectedProfileColor!.isEmpty) {
      return Theme.of(context).colorScheme.primary;
    }

    try {
      // Remove any '#' prefix if present
      String colorString = selectedProfileColor!.startsWith('#')
          ? selectedProfileColor!.substring(1)
          : selectedProfileColor!;

      // Ensure it's a valid hex string (3, 6, or 8 characters)
      if (colorString.length == 3) {
        // Convert 3-digit hex to 6-digit
        colorString = colorString.split('').map((c) => c * 2).join();
      } else if (colorString.length == 6) {
        // Valid 6-digit hex, add alpha
        colorString = 'FF$colorString';
      } else if (colorString.length == 8) {
        // Already has alpha, use as-is
      } else {
        // Invalid length, fallback to primary color
        return Theme.of(context).colorScheme.primary;
      }

      // Parse the hex string
      final int colorValue = int.parse(colorString, radix: 16);
      return Color(colorValue);
    } catch (e) {
      // If parsing fails, return primary color
      return Theme.of(context).colorScheme.primary;
    }
  }
}
