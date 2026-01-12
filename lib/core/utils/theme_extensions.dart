import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../theme/presentation/blocs/theme_bloc.dart';
import '../theme/presentation/blocs/theme_state.dart';

/// Расширения для BuildContext с динамическими цветами темы
///
/// Предоставляет удобный доступ к динамическим цветам приложения,
/// которые могут меняться в зависимости от состояния темы.
extension ThemeExtensions on BuildContext {
  /// Возвращает динамический основной цвет темы
  ///
  /// Получает текущий основной цвет из состояния ThemeBloc,
  /// или возвращает цвет по умолчанию если тема не загружена.
  Color get dynamicPrimaryColor {
    final themeState = read<ThemeBloc>().state;
    if (themeState is ThemeLoaded) {
      return themeState.colorScheme.primary;
    }
    // Fallback to default color
    return const Color(0xFFD0BCFF);
  }

  /// Возвращает динамический основной цвет с прозрачностью 20%
  Color get dynamicPrimaryColorWithOpacity => dynamicPrimaryColor.withValues(alpha: 0.2);

  /// Возвращает динамический основной цвет с прозрачностью 50%
  Color get dynamicPrimaryColorWithOpacity50 => dynamicPrimaryColor.withValues(alpha: 0.5);

  /// Возвращает начальный цвет динамического градиента (более насыщенный)
  ///
  /// Получает цвет из состояния ThemeBloc или возвращает цвет по умолчанию.
  /// Для дефолтной темы использует брендовый цвет, для пользовательских - использует primaryContainer.
  Color get dynamicGradientStart {
    final themeState = read<ThemeBloc>().state;
    if (themeState is ThemeLoaded) {
      final colorScheme = themeState.colorScheme;
      // Проверяем, является ли тема дефолтной (брендовой)
      final isDefaultTheme = colorScheme.primary.toARGB32() == 0xFFD0BCFF;
      
      if (isDefaultTheme) {
        // Дефолтная тема: используем брендовый цвет
        return const Color(0xFFB69DF8);
      } else {
        // Пользовательская тема: используем primaryContainer
        return colorScheme.primaryContainer;
      }
    }
    // Fallback to default gradient start
    return const Color(0xFFB69DF8);
  }

  /// Возвращает конечный цвет динамического градиента
  ///
  /// Получает цвет из состояния ThemeBloc или возвращает цвет по умолчанию.
  /// Для дефолтной темы использует брендовый цвет, для пользовательских - основной цвет темы.
  Color get dynamicGradientEnd {
    final themeState = read<ThemeBloc>().state;
    if (themeState is ThemeLoaded) {
      final colorScheme = themeState.colorScheme;
      // Проверяем, является ли тема дефолтной (брендовой)
      final isDefaultTheme = colorScheme.primary.toARGB32() == 0xFFD0BCFF;
      
      if (isDefaultTheme) {
        // Дефолтная тема: используем брендовый цвет
        return const Color(0xFFD0BCFF);
      } else {
        // Пользовательская тема: используем основной цвет
        return colorScheme.primary;
      }
    }
    // Fallback to default gradient end
    return const Color(0xFFD0BCFF);
  }

  /// Возвращает динамический основной градиент из двух цветов темы
  LinearGradient get dynamicPrimaryGradient {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        dynamicGradientStart,
        dynamicGradientEnd,
      ],
    );
  }

  /// Возвращает ColorScheme из темы (для удобства)
  ColorScheme get colorScheme {
    final themeState = read<ThemeBloc>().state;
    if (themeState is ThemeLoaded) {
      return themeState.colorScheme;
    }
    // Fallback to default color scheme
    return ColorScheme.fromSeed(
      seedColor: const Color(0xFFD0BCFF),
      brightness: Brightness.dark,
    );
  }
}
