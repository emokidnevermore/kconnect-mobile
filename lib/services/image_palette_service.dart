/// Сервис для извлечения цветовой палитры из изображений
///
/// Предоставляет функциональность для извлечения доминирующих цветов
/// из изображений с кэшированием результатов для производительности.
library;

import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Сервис для работы с цветовыми палитрами изображений
class ImagePaletteService {
  static final ImagePaletteService _instance = ImagePaletteService._internal();
  factory ImagePaletteService() => _instance;
  ImagePaletteService._internal();

  /// Кэш цветовых палитр по URL изображения
  final Map<String, PaletteGenerator> _paletteCache = {};

  /// Очередь URL для обработки (LRU кэш)
  final ListQueue<String> _cacheOrder = ListQueue<String>();

  /// Максимальный размер кэша
  static const int _maxCacheSize = 50;

  /// Получить цветовую палитру для изображения
  ///
  /// [imageUrl] - URL изображения
  /// Возвращает PaletteGenerator с извлеченными цветами или null при ошибке
  Future<PaletteGenerator?> getPalette(String imageUrl) async {
    // Проверяем кэш
    if (_paletteCache.containsKey(imageUrl)) {
      // Обновляем порядок в LRU кэше
      _cacheOrder.remove(imageUrl);
      _cacheOrder.addFirst(imageUrl);
      return _paletteCache[imageUrl];
    }

    try {
      // Создаем провайдер изображения
      final imageProvider = NetworkImage(imageUrl);

      // Извлекаем палитру
      final palette = await PaletteGenerator.fromImageProvider(
        imageProvider,
        size: const Size(100, 100), // Маленький размер для производительности
        region: const Rect.fromLTWH(0, 0, 100, 100), // Центральная область
        maximumColorCount: 8, // Ограничиваем количество цветов
      );

      // Сохраняем в кэш
      _addToCache(imageUrl, palette);

      return palette;
    } catch (e) {
      // В случае ошибки возвращаем null
      debugPrint('Failed to extract palette from $imageUrl: $e');
      return null;
    }
  }

  /// Получить градиент на основе палитры
  ///
  /// Создает LinearGradient из доминирующих цветов палитры
  LinearGradient? createGradientFromPalette(PaletteGenerator? palette) {
    if (palette == null) return null;

    final colors = <Color>[];

    // Добавляем доминирующие цвета в порядке приоритета
    if (palette.dominantColor != null) {
      colors.add(palette.dominantColor!.color);
    }
    if (palette.vibrantColor != null) {
      colors.add(palette.vibrantColor!.color);
    }
    if (palette.mutedColor != null) {
      colors.add(palette.mutedColor!.color);
    }
    if (palette.lightVibrantColor != null) {
      colors.add(palette.lightVibrantColor!.color);
    }
    if (palette.darkVibrantColor != null) {
      colors.add(palette.darkVibrantColor!.color);
    }

    // Если цветов недостаточно, используем дефолтные
    if (colors.length < 2) {
      colors.addAll([
        Colors.blue.withValues(alpha: 0.1),
        Colors.purple.withValues(alpha: 0.05),
      ]);
    }

    // Создаем градиент с низкой прозрачностью для мини-плеера
    final gradientColors = colors.take(3).map((color) =>
      color.withValues(alpha: 0.15) // Очень низкая прозрачность для производительности
    ).toList();

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradientColors,
      stops: _calculateStops(gradientColors.length),
    );
  }

  /// Рассчитать позиции цветов в градиенте
  List<double> _calculateStops(int colorCount) {
    if (colorCount <= 1) return [0.0];
    if (colorCount == 2) return [0.0, 1.0];

    final stops = <double>[];
    for (int i = 0; i < colorCount; i++) {
      stops.add(i / (colorCount - 1));
    }
    return stops;
  }

  /// Добавить палитру в кэш с LRU логикой
  void _addToCache(String url, PaletteGenerator palette) {
    // Если кэш переполнен, удаляем самый старый элемент
    if (_cacheOrder.length >= _maxCacheSize) {
      final oldestUrl = _cacheOrder.removeLast();
      _paletteCache.remove(oldestUrl);
    }

    // Добавляем новый элемент
    _cacheOrder.addFirst(url);
    _paletteCache[url] = palette;
  }

  /// Очистить кэш
  void clearCache() {
    _paletteCache.clear();
    _cacheOrder.clear();
  }

  /// Получить размер кэша (для отладки)
  int get cacheSize => _paletteCache.length;
}
