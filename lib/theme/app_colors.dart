/// Цветовая палитра приложения K-Connect
///
/// Предоставляет централизованную систему цветов для всего приложения.
/// Поддерживает динамическое обновление цветов на основе выбранной темы.
library;

import 'package:flutter/material.dart';

class AppColors {
  // Брендовые цвета дефолтной темы (фиксированные)
  static const Color _defaultThemePrimaryColor = Color(0xFFD0BCFF);
  static const Color _defaultThemeGradientStart = Color(0xFFB69DF8);
  static const Color _defaultThemeGradientEnd = Color(0xFFD0BCFF);
  static const int _defaultThemeColorValue = 0xFFD0BCFF;

  // ValueNotifier для реактивного обновления цветов
  static final ValueNotifier<Color> _primaryColorNotifier = ValueNotifier(const Color(0xFFD0BCFF));
  static final ValueNotifier<Color> _gradientStartNotifier = ValueNotifier(const Color(0xFFB69DF8));
  static final ValueNotifier<Color> _gradientEndNotifier = ValueNotifier(const Color(0xFFD0BCFF));

  // Текущие динамические цвета (изменяются от темы)
  static Color _currentPrimaryColor = const Color(0xFFD0BCFF);
  static Color _currentGradientStart = const Color(0xFFB69DF8);
  static Color _currentGradientEnd = const Color(0xFFD0BCFF);

  /// Проверяет, является ли тема дефолтной (брендовой)
  ///
  /// [colorScheme] - ColorScheme для проверки
  /// Возвращает true, если основной цвет темы равен дефолтному брендовому цвету
  static bool _isDefaultTheme(ColorScheme colorScheme) {
    // Проверяем значение основного цвета
    return colorScheme.primary.toARGB32() == _defaultThemeColorValue;
  }

  /// Обновляет динамические цвета на основе выбранного ColorScheme темы
  ///
  /// [colorScheme] - цветовая схема темы
  static void updateFromColorScheme(ColorScheme colorScheme) {
    _currentPrimaryColor = colorScheme.primary;

    // Для дефолтной темы используем брендовые цвета, для пользовательских - генерируем
    if (_isDefaultTheme(colorScheme)) {
      // Дефолтная тема: используем фиксированные брендовые цвета
      _currentGradientStart = _defaultThemeGradientStart;
      _currentGradientEnd = _defaultThemeGradientEnd;
    } else {
      // Пользовательская тема: используем цвета из ColorScheme
      // Используем primaryContainer как более светлый оттенок для градиента
      _currentGradientStart = colorScheme.primaryContainer;
      _currentGradientEnd = colorScheme.primary;
    }

    // Уведомляем слушателей об изменении цветов
    _primaryColorNotifier.value = _currentPrimaryColor;
    _gradientStartNotifier.value = _currentGradientStart;
    _gradientEndNotifier.value = _currentGradientEnd;
  }

  /// Обновляет динамические цвета на основе выбранного MaterialColor темы
  ///
  /// [themeColor] - цвет темы из MaterialColor, может быть null
  /// @deprecated Используйте updateFromColorScheme вместо этого
  static void updateFromMaterialColor(dynamic themeColor) {
    if (themeColor == null) {
      resetToDefault();
      return;
    }
    
    // Для обратной совместимости создаем ColorScheme из MaterialColor
    if (themeColor is ColorScheme) {
      updateFromColorScheme(themeColor);
    } else {
      // Если передан MaterialColor, создаем ColorScheme из seed цвета
      final seedColor = themeColor is MaterialColor ? themeColor.shade500 : const Color(0xFFD0BCFF);
      final colorScheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark);
      updateFromColorScheme(colorScheme);
    }
  }

  /// Сбрасывает цвета к значениям по умолчанию
  ///
  /// Примечание: не используется, но сохранено для консистентности
  static void resetToDefault() {
    _currentPrimaryColor = _defaultThemePrimaryColor;
    _currentGradientStart = _defaultThemeGradientStart;
    _currentGradientEnd = _defaultThemeGradientEnd;

    // Уведомляем слушателей об изменении
    _primaryColorNotifier.value = _currentPrimaryColor;
    _gradientStartNotifier.value = _currentGradientStart;
    _gradientEndNotifier.value = _currentGradientEnd;
  }

  // Основные брендовые цвета (динамические)

  /// Основной фиолетовый цвет (динамический, изменяется от темы)
  static Color get primaryPurple => _currentPrimaryColor;

  /// Начальный цвет градиента (динамический)
  static Color get gradientStart => _currentGradientStart;

  /// Конечный цвет градиента (динамический)
  static Color get gradientEnd => _currentGradientEnd;

  // Фоновые цвета (статические)

  /// Белый фон
  static const Color bgWhite = Color(0xFFFFFFFF);

  /// Темный фон основного интерфейса
  static const Color bgDark = Color(0xFF1C1C1C);

  /// Фон карточек и элементов
  static const Color bgCard = Color(0xFF171717);

  // Текстовые цвета (статические)

  /// Основной цвет текста
  static const Color textPrimary = Color(0xFFEAEAEA);

  /// Вторичный цвет текста
  static const Color textSecondary = Color(0xFFB0B0B0);

  // Цвета состояний (статические)

  /// Цвет успешных операций
  static const Color success = Color(0xFF50C878);

  /// Цвет ошибок и неудачных операций
  static const Color error = Color(0xFFFF5C5C);

  /// Цвет предупреждений
  static const Color warning = Color(0xFFFFD700);

  // Полупрозрачные цвета (статические)

  /// Темный полупрозрачный оверлей
  static const Color overlayDark = Color(0xAA000000);

  // Методы-хелперы для получения цветов из BuildContext (Material 3)
  // Используйте эти методы вместо статических констант для Material 3 совместимости

  /// Получить основной цвет текста из темы
  /// 
  /// [context] - BuildContext для доступа к теме
  /// Возвращает цвет из ColorScheme.onSurface
  static Color textPrimaryFromTheme(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  /// Получить вторичный цвет текста из темы
  /// 
  /// [context] - BuildContext для доступа к теме
  /// Возвращает цвет из ColorScheme.onSurfaceVariant
  static Color textSecondaryFromTheme(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  /// Получить темный фон из темы
  /// 
  /// [context] - BuildContext для доступа к теме
  /// Возвращает цвет из ColorScheme.surface
  static Color bgDarkFromTheme(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  /// Получить фон карточек из темы
  /// 
  /// [context] - BuildContext для доступа к теме
  /// Возвращает цвет из ColorScheme.surfaceContainerHighest
  static Color bgCardFromTheme(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  /// Получить белый фон из темы
  /// 
  /// [context] - BuildContext для доступа к теме
  /// Возвращает цвет из ColorScheme.onPrimary
  static Color bgWhiteFromTheme(BuildContext context) {
    return Theme.of(context).colorScheme.onPrimary;
  }

  /// Получить цвет ошибки из темы
  /// 
  /// [context] - BuildContext для доступа к теме
  /// Возвращает цвет из ColorScheme.error
  static Color errorFromTheme(BuildContext context) {
    return Theme.of(context).colorScheme.error;
  }

  /// Получить цвет успеха из темы
  /// 
  /// [context] - BuildContext для доступа к теме
  /// Возвращает цвет success (статический, Material 3 не имеет success в ColorScheme)
  static Color successFromTheme(BuildContext context) {
    // Material 3 не имеет success цвета в ColorScheme, используем статический
    return AppColors.success;
  }

  /// Получить цвет предупреждения из темы
  /// 
  /// [context] - BuildContext для доступа к теме
  /// Возвращает цвет warning (статический, Material 3 не имеет warning в ColorScheme)
  static Color warningFromTheme(BuildContext context) {
    // Material 3 не имеет warning цвета в ColorScheme, используем статический
    return AppColors.warning;
  }
}
