/// Глобальный сервис управления кэшем
///
/// Централизованный сервис для управления всеми типами кэша в приложении:
/// изображения, видео, аудио, данные профилей и другие данные.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/cache_size_calculator.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../injection.dart';
import 'cache_category.dart';
import 'video_cache_service.dart';
import 'audio_cache_service.dart';
import 'audio_preload_service.dart';

/// Глобальный сервис управления кэшем
class GlobalCacheService {
  /// Получает размеры кэша для всех категорий
  ///
  /// Returns: Map с размерами в байтах для каждой категории
  Future<Map<CacheCategory, int>> getCacheSizes() async {
    final sizes = <CacheCategory, int>{};
    
    sizes[CacheCategory.images] = await CacheSizeCalculator.getImageCacheSize();
    sizes[CacheCategory.videos] = await CacheSizeCalculator.getVideoCacheSize();
    sizes[CacheCategory.audio] = await CacheSizeCalculator.getAudioCacheSize();
    sizes[CacheCategory.profileData] = await CacheSizeCalculator.getProfileDataCacheSize();
    sizes[CacheCategory.other] = await CacheSizeCalculator.getOtherCacheSize();
    
    return sizes;
  }

  /// Получает общий размер кэша в байтах
  Future<int> getTotalCacheSize() async {
    final sizes = await getCacheSizes();
    int total = 0;
    for (final size in sizes.values) {
      total += size;
    }
    return total;
  }

  /// Очищает кэш для выбранных категорий
  ///
  /// [categories] - список категорий для очистки
  Future<void> clearCache(List<CacheCategory> categories) async {
    for (final category in categories) {
      switch (category) {
        case CacheCategory.images:
          await _clearImageCache();
          break;
        case CacheCategory.videos:
          await _clearVideoCache();
          break;
        case CacheCategory.audio:
          await _clearAudioCache();
          break;
        case CacheCategory.profileData:
          await _clearProfileDataCache();
          break;
        case CacheCategory.other:
          await _clearOtherCache();
          break;
      }
    }
  }

  /// Очищает весь кэш
  Future<void> clearAllCache() async {
    await clearCache(CacheCategory.values);
  }

  /// Очищает кэш изображений
  Future<void> _clearImageCache() async {
    try {
      // Очищаем Flutter imageCache
      imageCache.clear();
      imageCache.clearLiveImages();
      
      // Очищаем cached_network_image кэш
      // CachedNetworkImage использует DefaultCacheManager по умолчанию
      // Пытаемся очистить директории кэша
      try {
        final tempDir = await getTemporaryDirectory();
        final appDocDir = await getApplicationDocumentsDirectory();
        
        // cached_network_image кэширует в разных местах в зависимости от платформы
        final possiblePaths = [
          '${tempDir.path}/libCachedImageData',
          '${tempDir.path}/flutter_cache',
          '${tempDir.path}/image_cache',
          '${appDocDir.path}/../Library/Caches/libCachedImageData',
        ];
        
        for (final path in possiblePaths) {
          final imageCacheDir = Directory(path);
          if (await imageCacheDir.exists()) {
            try {
              await for (final entity in imageCacheDir.list(recursive: true)) {
                try {
                  if (entity is File) {
                    await entity.delete();
                  } else if (entity is Directory) {
                    await entity.delete(recursive: true);
                  }
                } catch (e) {
                  // Игнорируем ошибки удаления отдельных файлов
                }
              }
              // Пытаемся удалить саму директорию после очистки
              try {
                await imageCacheDir.delete(recursive: true);
              } catch (e) {
                // Игнорируем ошибки удаления директории
              }
            } catch (e) {
              // Игнорируем ошибки доступа к директории
            }
          }
        }
      } catch (e) {
        // Игнорируем ошибки доступа к директории кэша
      }
    } catch (e) {
      // Игнорируем ошибки очистки
    }
  }

  /// Очищает кэш видео
  Future<void> _clearVideoCache() async {
    try {
      // Очищаем постоянный кэш через VideoCacheService
      final videoCacheService = VideoCacheService.instance;
      await videoCacheService.clearCache();
    } catch (e) {
      // Игнорируем ошибки очистки
    }
  }

  /// Очищает кэш аудио
  Future<void> _clearAudioCache() async {
    try {
      // Очищаем постоянный кэш через AudioCacheService
      final audioCacheService = AudioCacheService.instance;
      await audioCacheService.clearCache();
      
      // Очищаем информацию о закешированных треках в AudioPreloadService
      final audioPreloadService = AudioPreloadService.instance;
      audioPreloadService.clearCacheInfo();
    } catch (e) {
      // Игнорируем ошибки очистки
    }
  }

  /// Очищает кэш данных профилей
  Future<void> _clearProfileDataCache() async {
    try {
      final profileRepository = locator<ProfileRepositoryImpl>();
      await profileRepository.clearCache();
    } catch (e) {
      // Игнорируем ошибки очистки
    }
  }

  /// Очищает другие данные из SharedPreferences
  Future<void> _clearOtherCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
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
        
        await prefs.remove(key);
      }
    } catch (e) {
      // Игнорируем ошибки очистки
    }
  }
}
