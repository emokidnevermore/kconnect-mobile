library;

import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/models/track.dart';
import '../../../../services/audio_service_manager.dart';
import '../../../../services/kconnect_audio_handler.dart';
import '../../../../services/cache/audio_cache_service.dart';

/// Реализация AudioRepository - простой прокси для команд
class AudioRepositoryImpl implements AudioRepository {
  AudioRepositoryImpl();

  @override
  Future<void> playTrack(Track track) async {
    await AudioServiceManager.ensureServiceReady();
    
    final handler = AudioServiceManager.getHandler();
    if (handler == null) {
      throw Exception('AudioHandler is not available');
    }
    
    final fullUrl = _ensureFullUrl(track.filePath);
    final coverUrl = track.coverPath != null ? _ensureFullUrl(track.coverPath!) : null;
    
    // Получаем кэшированный файл аудио
    final audioCacheService = AudioCacheService.instance;
    final cachedFile = await audioCacheService.getCachedAudioFile(fullUrl);
    
    // Используем путь к кэшированному файлу как ID для MediaItem
    // Это позволяет audio_service использовать локальный файл
    final cachedFilePath = cachedFile.path;
    
    final mediaItem = MediaItem(
      id: cachedFilePath, // Используем путь к кэшированному файлу
      title: track.title,
      artist: track.artist,
      duration: Duration(milliseconds: track.durationMs),
      artUri: coverUrl != null ? Uri.parse(coverUrl) : null,
      extras: {
        'trackId': track.id,
        'coverPath': track.coverPath,
        'isLiked': track.isLiked,
        'originalUrl': fullUrl, // Сохраняем оригинальный URL для справки
      },
    );
    
    // Проверяем, есть ли трек в текущей очереди audio_service
    final currentQueue = handler.queue.value;
    if (currentQueue.isNotEmpty) {
      final trackIndex = currentQueue.indexWhere((item) => item.id == fullUrl);
      if (trackIndex != -1) {
        // Трек найден в очереди - переключаемся на него
        if (kDebugMode) {
          debugPrint('AudioRepositoryImpl: playTrack - track found in queue at index $trackIndex, using skipToQueueItem');
        }
        await handler.skipToQueueItem(trackIndex);
        return;
      }
    }
    
    // Трек не в очереди - воспроизводим как одиночный трек
    // Это fallback для случаев, когда очередь не создана через QueueBloc
    if (kDebugMode) {
      debugPrint('AudioRepositoryImpl: playTrack - track not in queue, using playMediaItem');
    }
    await handler.playMediaItem(mediaItem);
  }

  @override
  Future<void> pause() async {
    final handler = AudioServiceManager.getHandler();
    if (handler != null) {
      await handler.pause();
    }
  }

  @override
  Future<void> resume() async {
    final handler = AudioServiceManager.getHandler();
    if (handler != null) {
      await handler.play();
    }
  }

  @override
  Future<void> stop() async {
    final handler = AudioServiceManager.getHandler();
    if (handler != null) {
      await handler.stop();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    final handler = AudioServiceManager.getHandler();
    if (handler != null) {
      await handler.seek(position);
    } else {
      throw Exception('AudioHandler is not available - cannot seek');
    }
  }

  void updateCommandAvailability({
    required bool canSkipNext,
    required bool canSkipPrevious,
  }) {
    final handler = AudioServiceManager.getHandler();
    if (kDebugMode) {
      debugPrint('AudioRepositoryImpl: updateCommandAvailability called with canSkipNext=$canSkipNext, canSkipPrevious=$canSkipPrevious');
      debugPrint('AudioRepositoryImpl: handler is ${handler?.runtimeType}, is KConnectAudioHandler: ${handler is KConnectAudioHandler}');
    }
    if (handler is KConnectAudioHandler) {
      handler.updateCommandAvailability(
        canSkipNext: canSkipNext,
        canSkipPrevious: canSkipPrevious,
      );
    }
  }

  void updateLikeState(bool isLiked) {
    final handler = AudioServiceManager.getHandler();
    if (handler is KConnectAudioHandler) {
      handler.updateLikeState(isLiked);
    }
  }

  void setOnSkipCallback(void Function(bool isNext) callback) {
    if (kDebugMode) {
      debugPrint('AudioRepositoryImpl: setOnSkipCallback called');
    }
    final handler = AudioServiceManager.getHandler();
    if (kDebugMode) {
      debugPrint('AudioRepositoryImpl: setOnSkipCallback - handler is ${handler?.runtimeType}, is KConnectAudioHandler: ${handler is KConnectAudioHandler}');
    }
    if (handler is KConnectAudioHandler) {
      handler.setOnSkipCallback(callback);
      if (kDebugMode) {
        debugPrint('AudioRepositoryImpl: setOnSkipCallback - callback set successfully');
      }
    } else {
      if (kDebugMode) {
        debugPrint('AudioRepositoryImpl: setOnSkipCallback - handler is not KConnectAudioHandler, cannot set callback');
      }
    }
  }

  String _ensureFullUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://k-connect.ru$url';
  }

  @override
  void dispose() {}
}
