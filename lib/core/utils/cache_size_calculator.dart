/// Утилиты для расчета размеров кэша
///
/// Предоставляет приблизительные оценки размеров различных типов кэша.
/// Используется для отображения информации о кэше в UI.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/cache/video_cache_service.dart';
import '../../services/cache/audio_cache_service.dart';

/// Калькулятор размеров кэша
class CacheSizeCalculator {
  /// Получает приблизительный размер кэша изображений в байтах
  ///
  /// Подсчитывает размер файлов в директории кэша cached_network_image
  /// для более точного расчета, который не зависит от liveImageCount.
  static Future<int> getImageCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      // cached_network_image использует DefaultCacheManager, который кэширует в разных местах
      final possiblePaths = [
        '${tempDir.path}/libCachedImageData',
        '${tempDir.path}/flutter_cache',
        '${tempDir.path}/image_cache',
      ];
      
      int totalSize = 0;
      for (final path in possiblePaths) {
        final imageCacheDir = Directory(path);
        if (await imageCacheDir.exists()) {
          try {
            await for (final entity in imageCacheDir.list(recursive: true)) {
              if (entity is File) {
                try {
                  final stat = await entity.stat();
                  totalSize += stat.size;
                } catch (e) {
                  // Игнорируем ошибки доступа к файлам
                }
              }
            }
          } catch (e) {
            // Игнорируем ошибки доступа к директории
          }
        }
      }
      
      // Также добавляем оценку для Flutter imageCache (в памяти)
      try {
        final imageCount = imageCache.liveImageCount;
        totalSize += imageCount * 100 * 1024; // ~100KB на изображение в памяти
      } catch (e) {
        // Игнорируем ошибки
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Получает приблизительный размер кэша видео в байтах
  ///
  /// Использует VideoCacheService для получения размера постоянного кэша.
  static Future<int> getVideoCacheSize() async {
    try {
      final videoCacheService = VideoCacheService.instance;
      return await videoCacheService.getCacheSize();
    } catch (e) {
      return 0;
    }
  }

  /// Получает приблизительный размер кэша аудио в байтах
  ///
  /// Использует AudioCacheService для получения размера постоянного кэша.
  static Future<int> getAudioCacheSize() async {
    try {
      final audioCacheService = AudioCacheService.instance;
      return await audioCacheService.getCacheSize();
    } catch (e) {
      return 0;
    }
  }

  /// Получает размер данных профилей из SharedPreferences в байтах
  ///
  /// Подсчитывает размер всех ключей, связанных с профилями.
  static Future<int> getProfileDataCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int totalSize = 0;
      for (final key in keys) {
        if (key.startsWith('profile_cache_') ||
            key.startsWith('current_profile_cache') ||
            key.startsWith('stats_cache_') ||
            key.startsWith('posts_cache_') ||
            key.startsWith('cache_timestamp_')) {
          // Приблизительная оценка размера значения
          final value = prefs.get(key);
          if (value is String) {
            totalSize += value.length * 2; // UTF-16 encoding
          } else if (value is List<String>) {
            totalSize += value.join().length * 2;
          } else if (value is int) {
            totalSize += 8; // 64-bit integer
          } else if (value is bool) {
            totalSize += 1; // boolean
          }
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Получает размер других данных из SharedPreferences в байтах
  ///
  /// Подсчитывает размер всех ключей, кроме сессий, настроек и данных профилей.
  static Future<int> getOtherCacheSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      int totalSize = 0;
      for (final key in keys) {
        // Исключаем сессии, настройки и данные профилей
        if (key == 'session_key' ||
            key.startsWith('use_profile_accent_color') ||
            key.startsWith('saved_accent_color') ||
            key.startsWith('tab_bar_glass_mode') ||
            key.startsWith('hide_tab_bar') ||
            key.startsWith('app_background') ||
            key.startsWith('profile_cache_') ||
            key.startsWith('current_profile_cache') ||
            key.startsWith('stats_cache_') ||
            key.startsWith('posts_cache_') ||
            key.startsWith('cache_timestamp_') ||
            key.startsWith('accounts') ||
            key.startsWith('active_account_index') ||
            key.startsWith('music_played_tracks_history_')) {
          continue;
        }
        
        // Приблизительная оценка размера значения
        final value = prefs.get(key);
        if (value is String) {
          totalSize += value.length * 2; // UTF-16 encoding
        } else if (value is List<String>) {
          totalSize += value.join().length * 2;
        } else if (value is int) {
          totalSize += 8; // 64-bit integer
        } else if (value is bool) {
          totalSize += 1; // boolean
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Форматирует размер в байтах в читаемый формат
  ///
  /// Примеры: "1.5 MB", "500 KB", "2 GB"
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }
}
