/// Градиенты приложения
///
/// Определяет градиентные цвета, используемые в интерфейсе приложения.
/// Основной градиент для акцентных элементов и кнопок.
/// Использует брендовые градиенты для дефолтной темы и динамические для пользовательских тем.
library;

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppGradients {
  // Брендовые градиенты для дефолтной темы (фиксированные)
  static const Color _defaultGradientStart = Color(0xFFB69DF8);
  static const Color _defaultGradientEnd = Color(0xFFD0BCFF);

  /// Получить основной градиент из темы
  /// 
  /// [context] - BuildContext для доступа к теме
  /// Возвращает градиент с брендовыми цветами для дефолтной темы
  /// или динамическими цветами из ColorScheme для пользовательских тем
  static LinearGradient primary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    // Проверяем, является ли тема дефолтной (брендовой)
    final isDefaultTheme = colorScheme.primary.toARGB32() == 0xFFD0BCFF;
    
    if (isDefaultTheme) {
      // Дефолтная тема: используем фиксированные брендовые градиенты
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _defaultGradientStart,
          _defaultGradientEnd,
        ],
      );
    } else {
      // Пользовательская тема: используем цвета из ColorScheme
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          colorScheme.primaryContainer,
          colorScheme.primary,
        ],
      );
    }
  }

  /// Статический градиент для обратной совместимости
  /// 
  /// Использует текущие динамические цвета из AppColors
  /// @deprecated Используйте primary(BuildContext) вместо этого
  @Deprecated('Use primary(BuildContext) instead for Material 3 compatibility')
  static LinearGradient get primaryStatic => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.gradientStart,
      AppColors.gradientEnd,
    ],
  );
}
