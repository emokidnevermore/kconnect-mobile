/// Стили текста приложения
///
/// Определяет все текстовые стили, используемые в приложении.
/// Использует Material Design 3 типографическую шкалу.
/// Цвета не задаются здесь, они берутся из Theme.of(context).textTheme и Theme.of(context).colorScheme.
library;

import 'package:flutter/material.dart';
import 'app_fonts.dart';

class AppTextStyles {
  // Заголовки — Mplus (Material 3 типографическая шкала)
  /// headlineMedium (28px) - для главных заголовков
  static final TextStyle h1 = TextStyle(
    fontFamily: AppFonts.mplus,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    decoration: TextDecoration.none,
  );

  /// headlineSmall (24px) - для подзаголовков
  static final TextStyle h2 = TextStyle(
    fontFamily: AppFonts.mplus,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  /// titleLarge (22px, округлено до 20px) - для заголовков секций
  static final TextStyle h3 = TextStyle(
    fontFamily: AppFonts.mplus,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.none,
  );

  // Основной текст — Poppins (Material 3 типографическая шкала)
  /// bodyLarge (16px) - для основного текста
  static const TextStyle body = TextStyle(
    fontFamily: AppFonts.poppins,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    decoration: TextDecoration.none,
  );

  /// bodyMedium (14px) - для вторичного текста
  static final TextStyle bodySecondary = TextStyle(
    fontFamily: AppFonts.poppins,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    decoration: TextDecoration.none,
  );

  /// labelLarge (14px, но используем 15px для кнопок) - для текста кнопок
  static final TextStyle button = TextStyle(
    fontFamily: AppFonts.poppins,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  /// labelLarge (14px, но используем 15px для кнопок) - для белого текста кнопок
  static final TextStyle buttonWhite = TextStyle(
    fontFamily: AppFonts.poppins,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
  );

  /// bodyLarge (16px) - для среднего текста
  static final bodyMedium = TextStyle(
    fontFamily: AppFonts.poppins,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    decoration: TextDecoration.none,
  );

  // Стили для постов (Material 3 типографическая шкала)
  /// titleSmall (14px) - для автора поста
  static final postAuthor = TextStyle(
    fontFamily: AppFonts.poppins,
    fontSize: 14,
    fontWeight: FontWeight.bold,
    decoration: TextDecoration.none,
  );

  /// bodySmall (12px) - для имени пользователя
  static final postUsername = TextStyle(
    fontFamily: AppFonts.poppins,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    decoration: TextDecoration.none,
  );

  /// bodyMedium (14px) - для содержимого поста
  static final postContent = TextStyle(
    fontFamily: AppFonts.poppins,
    fontSize: 14,
    decoration: TextDecoration.none,
  );

  /// bodySmall (12px) - для статистики поста
  static final postStats = TextStyle(
    fontFamily: AppFonts.poppins,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    decoration: TextDecoration.none,
  );

  /// bodySmall (12px) - для времени поста
  static final postTime = TextStyle(
    fontFamily: AppFonts.poppins,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    decoration: TextDecoration.none,
  );
}
