/// Категории кэша в приложении
///
/// Определяет все типы кэшируемых данных для управления и очистки.
library;

import 'package:flutter/material.dart';

enum CacheCategory {
  /// Кэш изображений (Flutter imageCache + cached_network_image)
  images,

  /// Кэш видео (video_player временные файлы)
  videos,

  /// Кэш аудио (just_audio временные файлы)
  audio,

  /// Данные профилей (SharedPreferences: profile_cache_*, posts_cache_*, stats_cache_*)
  profileData,

  /// Другие данные (остальные SharedPreferences, кроме сессий и настроек)
  other,
}

/// Расширение для CacheCategory с метаданными
extension CacheCategoryExtension on CacheCategory {
  /// Название категории для отображения
  String get displayName {
    switch (this) {
      case CacheCategory.images:
        return 'Изображения';
      case CacheCategory.videos:
        return 'Видео';
      case CacheCategory.audio:
        return 'Аудио';
      case CacheCategory.profileData:
        return 'Данные профилей';
      case CacheCategory.other:
        return 'Другое';
    }
  }

  /// Иконка категории
  IconData get icon {
    switch (this) {
      case CacheCategory.images:
        return Icons.image;
      case CacheCategory.videos:
        return Icons.video_library;
      case CacheCategory.audio:
        return Icons.music_note;
      case CacheCategory.profileData:
        return Icons.person;
      case CacheCategory.other:
        return Icons.storage;
    }
  }

  /// Цвет категории (Material Design 3)
  Color getColor(ColorScheme colorScheme) {
    switch (this) {
      case CacheCategory.images:
        return const Color(0xFF6750A4); // Primary
      case CacheCategory.videos:
        return const Color(0xFF625B71); // Secondary
      case CacheCategory.audio:
        return const Color(0xFF7D5260); // Tertiary
      case CacheCategory.profileData:
        return const Color(0xFF332D41); // Surface variant
      case CacheCategory.other:
        return colorScheme.onSurfaceVariant;
    }
  }

  /// Описание категории
  String get description {
    switch (this) {
      case CacheCategory.images:
        return 'Закешированные изображения и обложки';
      case CacheCategory.videos:
        return 'Временные файлы видео';
      case CacheCategory.audio:
        return 'Временные файлы аудио';
      case CacheCategory.profileData:
        return 'Кэшированные данные профилей и постов';
      case CacheCategory.other:
        return 'Прочие закешированные данные';
    }
  }
}
