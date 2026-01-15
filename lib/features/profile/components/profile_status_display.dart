/// Компонент отображения статуса пользователя с иконкой и цветом
///
/// Парсит текстовый статус пользователя, извлекает иконку и цвет,
/// отображает статус в стилизованном контейнере.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';

/// Виджет отображения статуса пользователя
///
/// Поддерживает разные иконки и цвета для статуса.
/// Формат статуса: {icon}text или просто text.
class ProfileStatusDisplay extends StatelessWidget {
  final String statusText;
  final String? statusColor;

  const ProfileStatusDisplay({
    super.key,
    required this.statusText,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    if (statusText.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final displayData = _parseStatusText(statusText);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: displayData.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: displayData.icon != null
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  displayData.icon!,
                  color: displayData.textColor,
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  displayData.text,
                  style: AppTextStyles.body.copyWith(color: displayData.textColor),
                ),
              ],
            )
          : Text(
              displayData.text,
              style: AppTextStyles.body.copyWith(color: displayData.textColor),
              textAlign: TextAlign.center,
            ),
    );
  }

  StatusDisplayData _parseStatusText(String statusText) {
    final backgroundColor = _parseColor(statusColor);
    final isBgLight = backgroundColor.computeLuminance() > 0.85;
    final textColor = isBgLight ? Colors.black : AppColors.textPrimary;

    // Parse icon and text: {icon}text
    if (statusText.startsWith('{')) {
      final closeBraceIndex = statusText.indexOf('}');
      if (closeBraceIndex > 1) {
        final iconName = statusText.substring(1, closeBraceIndex);
        final icon = _getStatusIcon(iconName);
        final text = statusText.substring(closeBraceIndex + 1).trim();

        return StatusDisplayData(
          text: text,
          icon: icon,
          backgroundColor: backgroundColor,
          textColor: textColor,
        );
      }
    }

    return StatusDisplayData(
      text: statusText,
      icon: null,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }

  Color _parseColor(String? statusColor) {
    if (statusColor == null || statusColor.isEmpty) {
      return const Color(0xFFFFFFFF); // Белый по умолчанию
    }

    try {
      // Убираем # если есть
      final colorStr = statusColor.startsWith('#')
          ? statusColor.substring(1)
          : statusColor;

      // Парсим hex цвет
      final colorInt = int.parse(colorStr, radix: 16);

      // Добавляем alpha если не указан
      if (colorStr.length == 6) {
        return Color(colorInt | 0xFF000000);
      } else if (colorStr.length == 8) {
        return Color(colorInt);
      } else {
        return const Color(0xFFFFFFFF);
      }
    } catch (e) {
      return const Color(0xFFFFFFFF);
    }
  }

  String? _getStatusIcon(String iconName) {
    switch (iconName) {
      case 'info':
        return 'lib/assets/icons/status_icons/info.svg';
      case 'cloud':
        return 'lib/assets/icons/status_icons/cloud.svg';
      case 'minion':
        return 'lib/assets/icons/status_icons/minion.svg';
      case 'heart':
        return 'lib/assets/icons/status_icons/heart.svg';
      case 'star':
        return 'lib/assets/icons/status_icons/star.svg';
      case 'music':
        return 'lib/assets/icons/status_icons/music.svg';
      case 'location':
        return 'lib/assets/icons/status_icons/location.svg';
      case 'cake':
        return 'lib/assets/icons/status_icons/cake.svg';
      case 'chat':
        return 'lib/assets/icons/status_icons/chat.svg';
      default:
        return null;
    }
  }
}

class StatusDisplayData {
  final String text;
  final String? icon;
  final Color backgroundColor;
  final Color textColor;

  const StatusDisplayData({
    required this.text,
    this.icon,
    required this.backgroundColor,
    required this.textColor,
  });
}
