/// Утилиты для работы с кешем изображений
///
/// Предоставляет функции для очистки кеша изображений Flutter
/// и получения информации о размере кеша.
/// Интегрирован с GlobalCacheService для централизованного управления.
library;

import 'package:flutter/material.dart';
import '../../services/cache/global_cache_service.dart';
import '../../services/cache/cache_category.dart';

/// Утилиты для управления кешем изображений Flutter
class CacheUtils {
  /// Очищает кеш изображений Flutter
  ///
  /// Удаляет все закешированные изображения и живые изображения из памяти.
  /// Используется при переключении аккаунтов или для освобождения памяти.
  /// Теперь использует GlobalCacheService для централизованного управления.
  static Future<void> clearImageCache() async {
    try {
      final cacheService = GlobalCacheService();
      await cacheService.clearCache([CacheCategory.images]);
    } catch (e) {
      // Handle error silently
    }
  }

  /// Получает размер кеша в читаемом формате
  ///
  /// Возвращает: Строку с примерной оценкой размера кеша в KB
  /// Примечание: Flutter не предоставляет прямой доступ к точному размеру кеша,
  /// поэтому используется приблизительная оценка на основе количества изображений.
  static String getCacheSize() {
    return 'Размер кеша: ~${(imageCache.liveImageCount * 100 / 1024).toStringAsFixed(1)} KB';
  }
}
