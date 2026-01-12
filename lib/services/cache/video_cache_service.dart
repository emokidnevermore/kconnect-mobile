/// Сервис кэширования видео
///
/// Предоставляет постоянное кэширование видеофайлов с использованием flutter_cache_manager.
/// Видео кэшируются локально и могут быть использованы оффлайн.
library;

import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// Сервис кэширования видео
class VideoCacheService {
  static VideoCacheService? _instance;
  static CacheManager? _cacheManager;

  VideoCacheService._();

  /// Получает экземпляр сервиса (singleton)
  static VideoCacheService get instance {
    _instance ??= VideoCacheService._();
    return _instance!;
  }

  /// Получает CacheManager для видео
  static CacheManager get cacheManager {
    _cacheManager ??= CacheManager(
      Config(
        'video_cache',
        stalePeriod: const Duration(days: 30), // Видео хранятся 30 дней
        maxNrOfCacheObjects: 100, // Максимум 100 видео в кэше
      ),
    );
    return _cacheManager!;
  }

  /// Получает кэшированный файл видео или загружает его
  ///
  /// [url] - URL видео для кэширования
  /// Returns: File с кэшированным видео
  Future<File> getCachedVideoFile(String url) async {
    final file = await cacheManager.getSingleFile(url);
    return file;
  }

  /// Проверяет, есть ли видео в кэше
  ///
  /// [url] - URL видео для проверки
  /// Returns: true если видео в кэше
  Future<bool> hasCachedVideo(String url) async {
    final file = await cacheManager.getFileFromCache(url);
    return file != null;
  }

  /// Предзагружает видео в кэш
  ///
  /// [url] - URL видео для предзагрузки
  Future<void> preloadVideo(String url) async {
    try {
      await cacheManager.getSingleFile(url);
    } catch (e) {
      // Игнорируем ошибки предзагрузки
    }
  }

  /// Очищает кэш видео
  Future<void> clearCache() async {
    try {
      // Очищаем через cacheManager
      await cacheManager.emptyCache();
      
      // Дополнительно очищаем директорию вручную на случай, если emptyCache не удалил все файлы
      try {
        final tempDir = await getTemporaryDirectory();
        // Проверяем несколько возможных путей кэша
        final possiblePaths = [
          '${tempDir.path}/video_cache',
          '${tempDir.path}/libCachedImageData/video_cache',
        ];
        
        for (final path in possiblePaths) {
          final cacheDir = Directory(path);
          if (await cacheDir.exists()) {
            try {
              await for (final entity in cacheDir.list(recursive: true)) {
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
              
              // Пытаемся удалить саму директорию
              try {
                await cacheDir.delete(recursive: true);
              } catch (e) {
                // Игнорируем ошибки удаления директории
              }
            } catch (e) {
              // Игнорируем ошибки доступа к директории
            }
          }
        }
      } catch (e) {
        // Игнорируем ошибки ручной очистки
      }
    } catch (e) {
      // Игнорируем ошибки очистки
    }
  }

  /// Получает размер кэша видео в байтах
  Future<int> getCacheSize() async {
    try {
      // Получаем директорию кэша из cacheManager
      final tempDir = await getTemporaryDirectory();
      // flutter_cache_manager хранит файлы в директории с именем кэша
      // Проверяем несколько возможных путей
      final possiblePaths = [
        '${tempDir.path}/video_cache',
        '${tempDir.path}/libCachedImageData/video_cache',
      ];
      
      int totalSize = 0;
      for (final path in possiblePaths) {
        final cacheDir = Directory(path);
        if (await cacheDir.exists()) {
          try {
            await for (final entity in cacheDir.list(recursive: true)) {
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
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}
