/// Сервис для загрузки и кэширования лирики треков
///
/// Предоставляет функциональность для получения синхронизированной
/// и обычной лирики с кэшированием результатов.
library;

import 'package:flutter/foundation.dart';
import '../features/music/domain/models/lyrics.dart';
import 'api_client/dio_client.dart';

/// Сервис для работы с лирикой треков
class LyricsService {
  static final LyricsService _instance = LyricsService._internal();
  factory LyricsService() => _instance;
  LyricsService._internal();

  final DioClient _client = DioClient();

  /// Кэш лирики по ID трека
  final Map<int, LyricsData> _lyricsCache = {};

  /// Получить лирику для трека
  ///
  /// [trackId] - ID трека
  /// Возвращает LyricsData или null при ошибке
  Future<LyricsData?> getLyrics(int trackId) async {
    // Проверяем кэш
    if (_lyricsCache.containsKey(trackId)) {
      return _lyricsCache[trackId];
    }

    try {
      final response = await _client.get('/api/music/$trackId/lyrics');

      if (response.statusCode == 200) {
        final lyricsData = LyricsData.fromJson(response.data);

        // Сохраняем в кэш
        _lyricsCache[trackId] = lyricsData;

        return lyricsData;
      }
    } catch (e) {
      // В случае ошибки возвращаем пустые данные лирики
      debugPrint('Failed to load lyrics for track $trackId: $e');

      // Создаем пустые данные лирики для кэширования
      final emptyLyrics = LyricsData(
        hasLyrics: false,
        hasSyncedLyrics: false,
        trackId: trackId,
      );
      _lyricsCache[trackId] = emptyLyrics;

      return emptyLyrics;
    }

    return null;
  }

  /// Загрузить лирику по URL (для случаев с lyrics_url)
  ///
  /// [lyricsUrl] - URL для загрузки лирики
  /// Возвращает LyricsData или null при ошибке
  Future<LyricsData?> loadLyricsFromUrl(String lyricsUrl) async {
    try {
      final response = await _client.get(lyricsUrl);

      if (response.statusCode == 200) {
        // Предполагаем, что lyrics_url возвращает synced_lyrics
        final syncedLyrics = (response.data as List)
            .map((item) => SyncedLyricLine.fromJson(item))
            .toList();

        return LyricsData(
          hasLyrics: false,
          hasSyncedLyrics: true,
          syncedLyrics: syncedLyrics,
        );
      }
    } catch (e) {
      debugPrint('Failed to load lyrics from URL $lyricsUrl: $e');
    }

    return null;
  }

  /// Очистить кэш
  void clearCache() {
    _lyricsCache.clear();
  }

  /// Получить размер кэша (для отладки)
  int get cacheSize => _lyricsCache.length;

  /// Проверить, есть ли лирика для трека в кэше
  bool hasLyricsInCache(int trackId) {
    return _lyricsCache.containsKey(trackId) &&
           _lyricsCache[trackId]?.hasAnyLyrics == true;
  }

  /// Получить кэшированную лирику для трека
  LyricsData? getCachedLyrics(int trackId) {
    return _lyricsCache[trackId];
  }
}
