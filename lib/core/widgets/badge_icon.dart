/// Виджет иконки с бейджем счетчика
///
/// Отображает иконку с наложенным бейджем, показывающим количество.
/// Поддерживает динамическое определение цвета текста бейджа
/// для обеспечения контрастности с фоновым цветом.
library;

import 'package:flutter/material.dart';
import '../../core/utils/theme_extensions.dart';

/// Виджет иконки с бейджем уведомлений
///
/// Компонент для отображения иконок с числовыми индикаторами.
/// Автоматически определяет цвет текста бейджа для обеспечения читаемости.
class BadgeIcon extends StatelessWidget {
  /// Виджет иконки для отображения
  final Widget icon;

  /// Количество для отображения в бейдже (0 = скрыть бейдж)
  final int count;

  /// Колбэк при нажатии на иконку
  final VoidCallback? onPressed;

  /// Конструктор виджета бейджа иконки
  const BadgeIcon({
    super.key,
    required this.icon,
    required this.count,
    this.onPressed,
  });

  /// Построение виджета иконки с бейджем
  ///
  /// Создает Stack с иконкой и наложенным бейджем (если count > 0).
  /// Бейдж использует динамический основной цвет с автоматическим
  /// подбором цвета текста для обеспечения контрастности.
  @override
  Widget build(BuildContext context) {
    final showBadge = count > 0;

    return Badge(
      isLabelVisible: showBadge,
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
      backgroundColor: context.dynamicPrimaryColor,
      textColor: _badgeTextColor(context),
      alignment: AlignmentDirectional.topEnd,
      offset: const Offset(4, -4),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        onPressed: onPressed,
        icon: icon,
      ),
    );
  }

  /// Определение цвета текста бейджа для обеспечения контрастности
  ///
  /// Если основной цвет светлый (близок к белому), использует черный текст.
  /// В противном случае использует основной цвет текста приложения.
  Color _badgeTextColor(BuildContext context) {
    final primary = context.dynamicPrimaryColor;
    // Если основной цвет светлый (близок к белому), используем черный текст для контраста
    return primary.computeLuminance() > 0.8 ? Colors.black : Theme.of(context).colorScheme.onPrimary;
  }
}
