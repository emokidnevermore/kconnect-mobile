/// Сервис кэширования аудио
///
/// Предоставляет постоянное кэширование аудиофайлов с использованием flutter_cache_manager.
/// Аудио кэшируются локально и могут быть использованы оффлайн.
library;

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'authorized_http_file_service.dart';

/// Сервис кэширования аудио
class AudioCacheService {
  static AudioCacheService? _instance;
  static CacheManager? _cacheManager;

  AudioCacheService._();

  /// Получает экземпляр сервиса (singleton)
  static AudioCacheService get instance {
    _instance ??= AudioCacheService._();
    return _instance!;
  }

  /// Получает CacheManager для аудио
  static CacheManager get cacheManager {
    _cacheManager ??= CacheManager(
      Config(
        'audio_cache',
        stalePeriod: const Duration(days: 30), // Аудио хранятся 30 дней
        maxNrOfCacheObjects: 200, // Максимум 200 треков в кэше
        fileService: AuthorizedHttpFileService(), // Используем кастомный FileService с авторизацией
      ),
    );
    return _cacheManager!;
  }

  /// Получает кэшированный файл аудио или загружает его
  ///
  /// [url] - URL аудио для кэширования
  /// [maxRetries] - максимальное количество попыток при ошибке
  /// Returns: File с кэшированным аудио
  Future<File> getCachedAudioFile(String url, {int maxRetries = 2}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        // Проверяем, есть ли файл в кэше
        final cachedFile = await cacheManager.getFileFromCache(url);
        if (cachedFile != null && await cachedFile.file.exists()) {
          // Файл уже в кэше
          if (kDebugMode) {
            debugPrint('AudioCacheService: Using cached file for $url');
          }
          return cachedFile.file;
        }
        
        // Файла нет в кэше - загружаем и кэшируем
        if (kDebugMode) {
          debugPrint('AudioCacheService: Downloading and caching file for $url');
        }
        final file = await cacheManager.getSingleFile(url);
        if (kDebugMode) {
          debugPrint('AudioCacheService: Successfully cached file for $url');
        }
        return file;
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          // Логируем ошибку только при последней попытке
          if (kDebugMode) {
            debugPrint('AudioCacheService: Failed to get cached audio file after $maxRetries attempts: $e');
          }
          // Если ошибка кэширования, пробуем загрузить напрямую через Dio
          // Это fallback на случай проблем с кэшированием
          rethrow;
        } else {
          // Ждем перед повторной попыткой
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }
    }
    throw Exception('Failed to get cached audio file after $maxRetries attempts');
  }

  /// Проверяет, есть ли аудио в кэше
  ///
  /// [url] - URL аудио для проверки
  /// Returns: true если аудио в кэше
  Future<bool> hasCachedAudio(String url) async {
    final file = await cacheManager.getFileFromCache(url);
    return file != null;
  }

  /// Предзагружает аудио в кэш
  ///
  /// [url] - URL аудио для предзагрузки
  /// [maxRetries] - максимальное количество попыток при ошибке
  Future<void> preloadAudio(String url, {int maxRetries = 2}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        // Проверяем, не закеширован ли уже файл
        final cachedFile = await cacheManager.getFileFromCache(url);
        if (cachedFile != null && await cachedFile.file.exists()) {
          // Файл уже в кэше
          return;
        }

        // Загружаем и кэшируем файл
        await cacheManager.getSingleFile(url);
        return;
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          // Логируем ошибку только при последней попытке
          if (kDebugMode) {
            debugPrint('AudioCacheService: Failed to preload audio after $maxRetries attempts: $e');
          }
        } else {
          // Ждем перед повторной попыткой
          await Future.delayed(Duration(milliseconds: 500 * attempts));
        }
      }
    }
  }

  /// Очищает кэш аудио
  Future<void> clearCache() async {
    try {
      // Очищаем через cacheManager
      await cacheManager.emptyCache();
      
      // Дополнительно очищаем директорию вручную на случай, если emptyCache не удалил все файлы
      try {
        final tempDir = await getTemporaryDirectory();
        // Проверяем несколько возможных путей кэша
        final possiblePaths = [
          '${tempDir.path}/audio_cache',
          '${tempDir.path}/libCachedImageData/audio_cache',
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

  /// Получает размер кэша аудио в байтах
  Future<int> getCacheSize() async {
    try {
      // flutter_cache_manager хранит файлы в разных местах в зависимости от платформы
      final tempDir = await getTemporaryDirectory();
      final appCacheDir = await getApplicationCacheDirectory();
      
      // Проверяем все возможные пути, где flutter_cache_manager может хранить файлы
      // flutter_cache_manager использует структуру: {baseDir}/libCachedImageData/{cacheName}/
      final possiblePaths = [
        // Стандартный путь для Android и других платформ
        '${tempDir.path}/libCachedImageData/audio_cache',
        // Альтернативный путь
        '${tempDir.path}/audio_cache',
        // Путь для iOS
        '${appCacheDir.path}/libCachedImageData/audio_cache',
        '${appCacheDir.path}/audio_cache',
        // Также проверяем корневую директорию libCachedImageData
        '${tempDir.path}/libCachedImageData',
        '${appCacheDir.path}/libCachedImageData',
      ];
      
      int totalSize = 0;
      final Set<String> processedFiles = {}; // Для избежания двойного подсчета
      int fileCount = 0;
      
      if (kDebugMode) {
        debugPrint('AudioCacheService: Checking cache directories...');
      }
      
      for (final path in possiblePaths) {
        final cacheDir = Directory(path);
        if (await cacheDir.exists()) {
          if (kDebugMode) {
            debugPrint('AudioCacheService: Checking directory: $path');
          }
          
          try {
            await for (final entity in cacheDir.list(recursive: true)) {
              if (entity is File) {
                try {
                  // Избегаем двойного подсчета одного и того же файла
                  if (processedFiles.contains(entity.path)) {
                    continue;
                  }
                  
                  // Проверяем, что это файл из нашего кеша (может быть по расширению или пути)
                  // flutter_cache_manager может хранить файлы с разными расширениями
                  final fileName = entity.path.toLowerCase();
                  // Пропускаем служебные файлы (например, .lock, .json и т.д.)
                  if (fileName.endsWith('.lock') || 
                      fileName.endsWith('.json') ||
                      fileName.endsWith('.tmp')) {
                    continue;
                  }
                  
                  processedFiles.add(entity.path);
                  
                  final stat = await entity.stat();
                  totalSize += stat.size;
                  fileCount++;
                  
                  if (kDebugMode && fileCount <= 10) {
                    // Логируем первые 10 файлов для отладки
                    debugPrint('AudioCacheService: Found cached file: ${entity.path}, size: ${stat.size} bytes');
                  }
                } catch (e) {
                  if (kDebugMode) {
                    debugPrint('AudioCacheService: Error getting file stat for ${entity.path}: $e');
                  }
                  // Игнорируем ошибки доступа к файлам
                }
              }
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('AudioCacheService: Error listing directory $path: $e');
            }
            // Игнорируем ошибки доступа к директории
          }
        } else {
          if (kDebugMode) {
            debugPrint('AudioCacheService: Directory does not exist: $path');
          }
        }
      }
      
      if (kDebugMode) {
        debugPrint('AudioCacheService: Total cache size: $totalSize bytes (${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB), files: $fileCount');
      }
      
      return totalSize;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioCacheService: Error getting cache size: $e');
      }
      return 0;
    }
  }
}
