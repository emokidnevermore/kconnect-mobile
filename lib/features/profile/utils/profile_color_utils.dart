import 'package:flutter/material.dart';
import '../../../core/utils/theme_extensions.dart';
import '../domain/models/user_profile.dart';

/// Утилитарный класс для операций с цветами профиля
class ProfileColorUtils {
  /// Получает акцентный цвет профиля, возвращаясь к динамическому основному цвету
  static Color getProfileAccentColor(UserProfile profile, BuildContext context) {
    if (profile.profileColor != null && profile.profileColor!.isNotEmpty) {
      try {
        final colorStr = profile.profileColor!.replaceFirst('#', '');
        final colorInt = int.parse(colorStr, radix: 16);
        return Color(colorInt | 0xFF000000);
      } catch (e) {
        // Некорректный цвет, возвращаемся к значению по умолчанию
      }
    }
    return context.dynamicPrimaryColor;
  }

  /// Проверяет, считается ли цвет белым (достаточно светлым)
  static bool isAccentWhite(Color accentColor) => accentColor.computeLuminance() > 0.85;

  /// Создает ColorScheme из акцентного цвета профиля
  ///
  /// Генерирует локальную ColorScheme Material Design 3 из акцентного цвета профиля.
  /// Используется для создания цветовой палитры фона и карточек профиля.
  /// 
  /// Обрабатывает особый случай белых/очень светлых цветов, для которых
  /// стандартная генерация ColorScheme.fromSeed может давать нежелательные зеленоватые оттенки.
  /// Для таких цветов создается полностью монохромная (черно-белая) тема.
  static ColorScheme createProfileColorScheme(Color accentColor) {
    final luminance = accentColor.computeLuminance();
    
    // Если цвет очень светлый (почти белый), создаем полностью монохромную черно-белую схему
    // чтобы избежать любых цветовых оттенков во всей палитре
    if (luminance > 0.85) {
      return _createMonochromeColorScheme(accentColor);
    }
    
    // Для обычных цветов используем стандартную генерацию
    return ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    );
  }

  /// Создает полностью монохромную (черно-белую) ColorScheme для светлых цветов
  ///
  /// Все цвета используют только серые оттенки без какой-либо цветности,
  /// что гарантирует отсутствие зеленоватых или других нежелательных оттенков.
  static ColorScheme _createMonochromeColorScheme(Color lightColor) {
    return ColorScheme.dark(
      primary: lightColor,
      onPrimary: Colors.black,
      primaryContainer: const Color(0xFF2C2C2C),
      onPrimaryContainer: Colors.white,
      secondary: const Color(0xFFB0B0B0),
      onSecondary: Colors.black,
      secondaryContainer: const Color(0xFF3A3A3A),
      onSecondaryContainer: const Color(0xFFE0E0E0),
      tertiary: const Color(0xFF909090),
      onTertiary: Colors.black,
      tertiaryContainer: const Color(0xFF3A3A3A),
      onTertiaryContainer: const Color(0xFFE0E0E0),
      error: const Color(0xFFCF6679),
      onError: Colors.black,
      errorContainer: const Color(0xFF4A2A2F),
      onErrorContainer: const Color(0xFFF9DEDC),
      surface: const Color(0xFF1C1C1C),
      onSurface: Colors.white,
      surfaceContainerLowest: const Color(0xFF0F0F0F),
      surfaceContainerLow: const Color(0xFF282828),
      surfaceContainer: const Color(0xFF2C2C2C),
      surfaceContainerHigh: const Color(0xFF363636),
      surfaceContainerHighest: const Color(0xFF414141),
      outline: const Color(0xFF6C6C6C),
      outlineVariant: const Color(0xFF444444),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFFE0E0E0),
      onInverseSurface: Colors.black,
      inversePrimary: Colors.black,
    );
  }
}
