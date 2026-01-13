/// Сервис предзагрузки аудио
///
/// Управляет автоматической предзагрузкой аудиофайлов для улучшения
/// пользовательского опыта. Поддерживает приоритеты и ограничения
/// на количество одновременных загрузок.
library;

import 'package:flutter/foundation.dart';
import '../../features/music/domain/models/track.dart';
import 'audio_cache_service.dart';

/// Приоритет предзагрузки трека
enum PreloadPriority {
  /// Текущий трек (высший приоритет)
  current,
  /// Следующий трек в очереди
  next,
  /// Предыдущий трек в очереди
  previous,
  /// Видимые треки на экране
  visible,
  /// Треки, которые скоро появятся на экране
  upcoming,
}

/// Задача предзагрузки
class _PreloadTask {
  final Track track;
  final PreloadPriority priority;
  final DateTime createdAt;
  bool isCompleted = false;
  bool isCancelled = false;

  _PreloadTask({
    required this.track,
    required this.priority,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get priorityValue {
    switch (priority) {
      case PreloadPriority.current:
        return 0;
      case PreloadPriority.next:
        return 1;
      case PreloadPriority.previous:
        return 2;
      case PreloadPriority.visible:
        return 3;
      case PreloadPriority.upcoming:
        return 4;
    }
  }
}

/// Сервис предзагрузки аудио
class AudioPreloadService {
  static AudioPreloadService? _instance;
  final AudioCacheService _cacheService = AudioCacheService.instance;
  
  // Очередь задач предзагрузки
  final List<_PreloadTask> _preloadQueue = [];
  // Текущие активные загрузки
  final Set<String> _activePreloads = {};
  // Максимальное количество одновременных загрузок
  static const int _maxConcurrentPreloads = 3;
  // Треки, которые уже закешированы
  final Set<String> _cachedTracks = {};

  AudioPreloadService._();

  /// Получает экземпляр сервиса (singleton)
  static AudioPreloadService get instance {
    _instance ??= AudioPreloadService._();
    return _instance!;
  }

  /// Предзагружает список треков
  ///
  /// [tracks] - список треков для предзагрузки
  /// [priority] - приоритет предзагрузки (по умолчанию upcoming)
  Future<void> preloadTracks(
    List<Track> tracks, {
    PreloadPriority priority = PreloadPriority.upcoming,
  }) async {
    for (final track in tracks) {
      await preloadTrack(track, priority: priority);
    }
  }

  /// Предзагружает один трек
  ///
  /// [track] - трек для предзагрузки
  /// [priority] - приоритет предзагрузки
  Future<void> preloadTrack(
    Track track, {
    PreloadPriority priority = PreloadPriority.upcoming,
  }) async {
    final trackId = track.id.toString();

    // Пропускаем, если трек уже закеширован
    if (_cachedTracks.contains(trackId)) {
      if (kDebugMode) {
        debugPrint('AudioPreloadService: Track $trackId already cached, skipping');
      }
      return;
    }

    // Пропускаем, если трек уже в очереди или загружается
    if (_preloadQueue.any((task) => task.track.id == track.id && !task.isCancelled) ||
        _activePreloads.contains(trackId)) {
      if (kDebugMode) {
        debugPrint('AudioPreloadService: Track $trackId already in queue or loading, skipping');
      }
      return;
    }

    // Добавляем задачу в очередь
    final task = _PreloadTask(track: track, priority: priority);
    _preloadQueue.add(task);
    _preloadQueue.sort((a, b) => a.priorityValue.compareTo(b.priorityValue));

    if (kDebugMode) {
      debugPrint('AudioPreloadService: Added track ${track.title} to preload queue with priority ${priority.name}');
    }

    // Запускаем обработку очереди
    _processQueue();
  }

  /// Предзагружает видимые треки
  ///
  /// [tracks] - список всех треков
  /// [startIndex] - начальный индекс видимых треков
  /// [endIndex] - конечный индекс видимых треков
  Future<void> preloadVisibleTracks(
    List<Track> tracks,
    int startIndex,
    int endIndex,
  ) async {
    final visibleTracks = tracks.sublist(
      startIndex.clamp(0, tracks.length),
      endIndex.clamp(0, tracks.length),
    );

    // Предзагружаем видимые треки
    await preloadTracks(visibleTracks, priority: PreloadPriority.visible);

    // Предзагружаем треки, которые скоро появятся (за 2-3 позиции до видимости)
    final upcomingStart = (startIndex - 3).clamp(0, tracks.length);
    final upcomingEnd = startIndex.clamp(0, tracks.length);
    if (upcomingStart < upcomingEnd) {
      final upcomingTracks = tracks.sublist(upcomingStart, upcomingEnd);
      await preloadTracks(upcomingTracks, priority: PreloadPriority.upcoming);
    }
  }

  /// Предзагружает следующий трек в очереди
  ///
  /// [currentTrack] - текущий трек
  /// [queueTracks] - все треки в очереди
  /// [currentIndex] - текущий индекс в очереди
  Future<void> preloadNextTrackInQueue(
    Track? currentTrack,
    List<Track> queueTracks,
    int currentIndex,
  ) async {
    // Предзагружаем текущий трек (если еще не закеширован)
    if (currentTrack != null) {
      await preloadTrack(currentTrack, priority: PreloadPriority.current);
    }

    // Предзагружаем следующий трек
    if (currentIndex + 1 < queueTracks.length) {
      final nextTrack = queueTracks[currentIndex + 1];
      await preloadTrack(nextTrack, priority: PreloadPriority.next);
    }

    // Предзагружаем предыдущий трек (для возможности перемотки назад)
    if (currentIndex > 0) {
      final previousTrack = queueTracks[currentIndex - 1];
      await preloadTrack(previousTrack, priority: PreloadPriority.previous);
    }
  }

  /// Отменяет предзагрузку трека
  ///
  /// [trackId] - ID трека для отмены
  void cancelPreload(int trackId) {
    // Отменяем задачи в очереди
    for (final task in _preloadQueue) {
      if (task.track.id == trackId) {
        task.isCancelled = true;
      }
    }
    _preloadQueue.removeWhere((task) => task.isCancelled);

    if (kDebugMode) {
      debugPrint('AudioPreloadService: Cancelled preload for track $trackId');
    }
  }

  /// Отменяет все предзагрузки
  void cancelAllPreloads() {
    _preloadQueue.clear();
    _activePreloads.clear();

    if (kDebugMode) {
      debugPrint('AudioPreloadService: Cancelled all preloads');
    }
  }

  /// Обрабатывает очередь предзагрузки
  void _processQueue() async {
    // Пока есть место для новых загрузок и задачи в очереди
    while (_activePreloads.length < _maxConcurrentPreloads && _preloadQueue.isNotEmpty) {
      // Берем задачу с наивысшим приоритетом
      final task = _preloadQueue.firstWhere(
        (t) => !t.isCompleted && !t.isCancelled,
        orElse: () => _preloadQueue.first,
      );

      if (task.isCancelled) {
        _preloadQueue.remove(task);
        continue;
      }

      _preloadQueue.remove(task);
      final trackId = task.track.id.toString();
      _activePreloads.add(trackId);

      // Запускаем предзагрузку асинхронно
      _preloadTrackAsync(task).then((_) {
        _activePreloads.remove(trackId);
        // Продолжаем обработку очереди
        _processQueue();
      });
    }
  }

  /// Асинхронная предзагрузка трека
  Future<void> _preloadTrackAsync(_PreloadTask task) async {
    if (task.isCancelled) {
      return;
    }

    try {
      final trackUrl = _getFullUrl(task.track.filePath);
      
      // Проверяем, не закеширован ли уже трек
      final isCached = await _cacheService.hasCachedAudio(trackUrl);
      if (isCached) {
        if (kDebugMode) {
          debugPrint('AudioPreloadService: Track ${task.track.id} already cached');
        }
        _cachedTracks.add(task.track.id.toString());
        task.isCompleted = true;
        return;
      }

      if (kDebugMode) {
        debugPrint('AudioPreloadService: Preloading track ${task.track.id} (${task.track.title})');
      }

      // Предзагружаем трек
      await _cacheService.preloadAudio(trackUrl);

      _cachedTracks.add(task.track.id.toString());
      task.isCompleted = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioPreloadService: Failed to preload track ${task.track.id}');
      }
      // Не помечаем как завершенный, чтобы можно было повторить позже
    }
  }

  /// Получает полный URL из пути
  String _getFullUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return 'https://k-connect.ru$path';
  }

  /// Очищает информацию о закешированных треках
  /// (вызывается при очистке кеша)
  void clearCacheInfo() {
    _cachedTracks.clear();
  }
}
