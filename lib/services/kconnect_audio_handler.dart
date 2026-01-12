import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Callback для обработки команд next/previous
typedef OnSkipCallback = void Function(bool isNext);

/// Static service для связи между isolate'ами
class _SkipCallbackService {
  static OnSkipCallback? _callback;
  static void setCallback(OnSkipCallback? callback) => _callback = callback;
  static OnSkipCallback? getCallback() => _callback;
}

/// AudioHandler для интеграции с audio_service
/// Минимальная реализация - просто транслирует команды в AudioPlayer
class KConnectAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  OnSkipCallback? _onSkipCallback;

  KConnectAudioHandler() {
    // Автоматическая трансляция событий из just_audio в audio_service
    // Используем listen вместо pipe, чтобы избежать конфликта
    _player.playbackEventStream.map(_transformEvent).listen((state) {
      playbackState.add(state);
    });
    
    // Восстанавливаем callback из static service
    _onSkipCallback = _SkipCallbackService.getCallback();
  }

  @override
  Future<void> playMediaItem(MediaItem mediaItem) async {
    if (kDebugMode) {
      debugPrint('KConnectAudioHandler: playMediaItem called for track: ${mediaItem.title}, queue length: ${queue.value.length}');
    }
    
    // Если очередь уже установлена (синхронизирована из QueueBloc), используем её
    if (queue.value.length > 1) {
      // Очередь уже синхронизирована из QueueBloc, просто переключаемся на нужный трек
      final currentIndex = queue.value.indexWhere((item) => item.id == mediaItem.id);
      if (currentIndex != -1) {
        // Трек уже в очереди, переключаемся на него
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: playMediaItem - track found in queue at index $currentIndex, switching to it');
        }
        // Устанавливаем mediaItem перед переключением
        this.mediaItem.value = mediaItem;
        await _player.seek(Duration.zero, index: currentIndex);
        await _player.play();
        return;
      } else {
        // Трека нет в очереди, но очередь уже есть - добавляем его в очередь
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: playMediaItem - track not found in queue, but queue exists. Adding to queue.');
        }
        // Добавляем трек в очередь и переключаемся на него
        final updatedQueue = [...queue.value, mediaItem];
        queue.value = updatedQueue;
        final newIndex = updatedQueue.length - 1;
        
        // Обновляем плейлист в just_audio
        final audioSources = updatedQueue.map((item) => 
          _createAudioSource(item.id)
        ).toList();
        
        await _player.setAudioSources(audioSources, initialIndex: newIndex);
        this.mediaItem.value = mediaItem;
        await _player.play();
        return;
      }
    }
    
    // Если очередь пустая или содержит один трек, ждем синхронизации из QueueBloc
    // Но если синхронизация не произошла, устанавливаем один трек как fallback
    if (kDebugMode) {
      debugPrint('KConnectAudioHandler: playMediaItem - queue is empty or has 1 track (length=${queue.value.length}), waiting for queue sync or setting single track');
    }
    
    // Устанавливаем mediaItem
    this.mediaItem.value = mediaItem;
    
    // Если очередь пустая, устанавливаем один трек
    if (queue.value.isEmpty) {
      queue.value = [mediaItem];
      await _player.setAudioSource(_createAudioSource(mediaItem.id));
      await _player.play();
    } else {
      // Очередь содержит один трек - возможно, синхронизация еще не произошла
      // Проверяем, совпадает ли текущий трек с запрошенным
      if (queue.value.first.id == mediaItem.id) {
        // Тот же трек - просто запускаем воспроизведение
        await _player.play();
      } else {
        // Другой трек - обновляем очередь
        queue.value = [mediaItem];
        await _player.setAudioSource(_createAudioSource(mediaItem.id));
        await _player.play();
      }
    }
    
    // Состояние обновится автоматически через playbackEventStream
  }

  /// Создает AudioSource из ID (может быть путь к файлу или URL)
  AudioSource _createAudioSource(String id) {
    // Проверяем, является ли ID путем к локальному файлу
    // Локальные файлы обычно не начинаются с http:// или https://
    if (id.startsWith('http://') || id.startsWith('https://')) {
      // Это URL - используем AudioSource.uri
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: Creating AudioSource from URL: $id');
      }
      return AudioSource.uri(Uri.parse(id));
    } else {
      // Это путь к файлу - используем AudioSource.file
      // Проверяем, начинается ли путь с file://
      final filePath = id.startsWith('file://') ? id.substring(7) : id;
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: Creating AudioSource from file path: $filePath');
      }
      return AudioSource.file(filePath);
    }
  }

  @override
  Future<void> play() async {
    await _player.play();
    // Состояние обновится автоматически через playingStream.listen
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    // Состояние обновится автоматически через playbackEventStream
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Публичный метод для обновления очереди напрямую
  /// Используется вместо customAction для надежности
  Future<void> updateQueueDirectly({
    required List<MediaItem> mediaItems,
    required int currentIndex,
    required bool autoPlay,
  }) async {
    if (kDebugMode) {
      debugPrint('KConnectAudioHandler: updateQueueDirectly called with ${mediaItems.length} tracks, currentIndex=$currentIndex, autoPlay=$autoPlay');
    }
    
    try {
      final clampedIndex = currentIndex.clamp(0, mediaItems.length - 1);
      
      // Всегда устанавливаем полную очередь через ConcatenatingAudioSource
      queue.value = mediaItems;
      
      final audioSources = mediaItems.map((item) => 
        _createAudioSource(item.id)
      ).toList();
      
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: Setting audio source with ${audioSources.length} sources, initialIndex=$clampedIndex');
      }
      
      await _player.setAudioSources(audioSources, initialIndex: clampedIndex);
      
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: Audio source set, currentIndex=${_player.currentIndex}, processingState=${_player.processingState}');
      }
      
      // Устанавливаем текущий mediaItem
      if (clampedIndex >= 0 && clampedIndex < mediaItems.length) {
        mediaItem.value = mediaItems[clampedIndex];
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: MediaItem set to: ${mediaItems[clampedIndex].title}');
        }
      }
      
      // Запускаем воспроизведение только если autoPlay=true
      if (autoPlay) {
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: autoPlay=true, calling _player.play()');
        }
        await _player.play();
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: Queue updated - ${mediaItems.length} tracks, currentIndex=$clampedIndex, autoPlay=true, playing started');
          debugPrint('KConnectAudioHandler: Player state after play - playing=${_player.playing}, processingState=${_player.processingState}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: Queue updated - ${mediaItems.length} tracks, currentIndex=$clampedIndex, autoPlay=false');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: Error in updateQueueDirectly: $e');
        debugPrint('KConnectAudioHandler: Stack trace: $stackTrace');
      }
    }
  }

  @override
  Future<void> skipToNext() async {
    if (kDebugMode) {
      debugPrint('KConnectAudioHandler: skipToNext called, queue length: ${queue.value.length}, currentIndex: ${_player.currentIndex}');
    }
    
    // Если очередь пустая или состоит из одного трека, используем callback
    if (queue.value.isEmpty || queue.value.length == 1) {
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: skipToNext - queue is empty or has 1 item, using callback');
      }
      if (_onSkipCallback != null) {
        _onSkipCallback!(true);
      }
      return;
    }
    
    // Если в очереди несколько треков, используем встроенную функциональность just_audio
    try {
      final currentIndex = _player.currentIndex ?? 0;
      if (currentIndex < queue.value.length - 1) {
        await _player.seekToNext();
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: skipToNext - seekToNext succeeded, new index: ${_player.currentIndex}');
        }
        // Обновляем mediaItem после переключения
        final newIndex = _player.currentIndex ?? 0;
        if (newIndex >= 0 && newIndex < queue.value.length) {
          mediaItem.value = queue.value[newIndex];
        }
        return;
      } else {
        // Достигли конца очереди, используем callback для загрузки следующей страницы
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: skipToNext - reached end of queue, using callback');
        }
        if (_onSkipCallback != null) {
          _onSkipCallback!(true);
        }
        return;
      }
    } catch (e) {
      // Если не получилось, используем callback как fallback
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: skipToNext - seekToNext failed: $e, using callback');
      }
      if (_onSkipCallback != null) {
        _onSkipCallback!(true);
      }
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (kDebugMode) {
      debugPrint('KConnectAudioHandler: skipToPrevious called, queue length: ${queue.value.length}, currentIndex: ${_player.currentIndex}');
    }
    
    // Если очередь пустая или состоит из одного трека, используем callback
    if (queue.value.isEmpty || queue.value.length == 1) {
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: skipToPrevious - queue is empty or has 1 item, using callback');
      }
      if (_onSkipCallback != null) {
        _onSkipCallback!(false);
      }
      return;
    }
    
    // Если в очереди несколько треков, используем встроенную функциональность just_audio
    try {
      final currentIndex = _player.currentIndex ?? 0;
      if (currentIndex > 0) {
        await _player.seekToPrevious();
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: skipToPrevious - seekToPrevious succeeded, new index: ${_player.currentIndex}');
        }
        // Обновляем mediaItem после переключения
        final newIndex = _player.currentIndex ?? 0;
        if (newIndex >= 0 && newIndex < queue.value.length) {
          mediaItem.value = queue.value[newIndex];
        }
        return;
      } else {
        // Достигли начала очереди, используем callback
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: skipToPrevious - reached start of queue, using callback');
        }
        if (_onSkipCallback != null) {
          _onSkipCallback!(false);
        }
        return;
      }
    } catch (e) {
      // Если не получилось, используем callback как fallback
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: skipToPrevious - seekToPrevious failed: $e, using callback');
      }
      if (_onSkipCallback != null) {
        _onSkipCallback!(false);
      }
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= queue.value.length) {
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: skipToQueueItem - invalid index $index (queue length: ${queue.value.length})');
      }
      return;
    }
    
    if (kDebugMode) {
      debugPrint('KConnectAudioHandler: skipToQueueItem - switching to index $index');
    }
    
    // Переключаемся на нужный трек в очереди
    await _player.seek(Duration.zero, index: index);
    
    // Обновляем mediaItem сразу после переключения
    if (index >= 0 && index < queue.value.length) {
      mediaItem.value = queue.value[index];
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: skipToQueueItem - MediaItem updated to: ${queue.value[index].title}');
      }
    }
    
    await _player.play();
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (kDebugMode) {
      debugPrint('KConnectAudioHandler: customAction called - name=$name, extras keys=${extras?.keys.toList()}');
    }
    
    if (name == 'seek' && extras != null) {
      final positionMs = extras['position'] as int?;
      if (positionMs != null) {
        await seek(Duration(milliseconds: positionMs));
      }
    } else if (name == 'updateCommandAvailability' && extras != null) {
      // Этот метод больше не используется активно, так как флаги вычисляются динамически
      // Оставлено для обратной совместимости
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: customAction updateCommandAvailability - flags are now computed dynamically, ignoring');
      }
      // Обновляем PlaybackState, чтобы кнопки обновились
      final updatedState = _transformEvent(_player.playbackEvent);
      playbackState.add(updatedState);
    } else if (name == 'updateLikeState' && extras != null) {
      final isLiked = extras['isLiked'] as bool? ?? false;
      if (mediaItem.value != null) {
        final currentItem = mediaItem.value!;
        mediaItem.value = currentItem.copyWith(
          extras: {
            ...?currentItem.extras,
            'isLiked': isLiked,
          },
        );
      }
    } else if (name == 'skipCallback') {
      // Обработка skip через customAction для работы между isolate'ами
      // extras должен содержать 'isNext': true/false
      // Этот customAction вызывается из основного isolate для передачи команды в audio_service isolate
      final isNext = extras?['isNext'] as bool? ?? false;
      if (_onSkipCallback != null) {
        _onSkipCallback!(isNext);
      }
    } else if (name == 'setSkipCallback') {
      // Установка callback через customAction (не используется, но оставлено для совместимости)
      // Callback должен быть установлен через setOnSkipCallback из основного isolate
    } else if (name == 'addQueueItem' && extras != null) {
      // Добавление трека в существующую очередь (для динамического построения очереди через callback)
      try {
        final mediaItemData = extras['mediaItem'] as Map<String, dynamic>?;
        if (mediaItemData != null) {
          final newMediaItem = MediaItem(
            id: mediaItemData['id'] as String,
            title: mediaItemData['title'] as String? ?? '',
            artist: mediaItemData['artist'] as String? ?? '',
            duration: mediaItemData['duration'] != null 
                ? Duration(milliseconds: mediaItemData['duration'] as int)
                : null,
            artUri: mediaItemData['artUri'] != null 
                ? Uri.parse(mediaItemData['artUri'] as String)
                : null,
            extras: mediaItemData['extras'] as Map<String, dynamic>?,
          );
          
          // Добавляем трек в очередь
          final updatedQueue = [...queue.value, newMediaItem];
          queue.value = updatedQueue;
          
          // Обновляем плейлист в just_audio
          final audioSources = updatedQueue.map((item) => 
            AudioSource.uri(Uri.parse(item.id))
          ).toList();
          
          // Сохраняем текущий индекс
          final currentIndex = _player.currentIndex ?? 0;
          
          await _player.setAudioSources(audioSources, initialIndex: currentIndex);
          
          if (kDebugMode) {
            debugPrint('KConnectAudioHandler: Added track to queue - ${newMediaItem.title}, queue length: ${updatedQueue.length}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: Error adding track to queue: $e');
        }
      }
    } else if (name == 'updateQueue' && extras != null) {
      // Синхронизация очереди из QueueBloc с системным плеером
      // Всегда устанавливаем полную очередь - просто и надежно
      if (kDebugMode) {
        debugPrint('KConnectAudioHandler: updateQueue customAction received');
      }
      try {
        final mediaItemsData = extras['mediaItems'] as List<dynamic>?;
        final currentIndex = extras['currentIndex'] as int? ?? 0;
        final autoPlay = extras['autoPlay'] as bool? ?? false;
        
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: updateQueue - mediaItemsData=${mediaItemsData?.length}, currentIndex=$currentIndex, autoPlay=$autoPlay');
        }
        
        if (mediaItemsData != null && mediaItemsData.isNotEmpty) {
          // Преобразуем данные в MediaItem
          final mediaItems = mediaItemsData.map((data) {
            final map = data as Map<String, dynamic>;
            return MediaItem(
              id: map['id'] as String,
              title: map['title'] as String? ?? '',
              artist: map['artist'] as String? ?? '',
              duration: map['duration'] != null 
                  ? Duration(milliseconds: map['duration'] as int)
                  : null,
              artUri: map['artUri'] != null 
                  ? Uri.parse(map['artUri'] as String)
                  : null,
              extras: map['extras'] as Map<String, dynamic>?,
            );
          }).toList();
          
          final clampedIndex = currentIndex.clamp(0, mediaItems.length - 1);
          
          // Всегда устанавливаем полную очередь через ConcatenatingAudioSource
          queue.value = mediaItems;
          
          final audioSources = mediaItems.map((item) => 
            AudioSource.uri(Uri.parse(item.id))
          ).toList();
          
          if (kDebugMode) {
            debugPrint('KConnectAudioHandler: Setting audio source with ${audioSources.length} sources, initialIndex=$clampedIndex');
          }
          
          await _player.setAudioSources(audioSources, initialIndex: clampedIndex);
          
          if (kDebugMode) {
            debugPrint('KConnectAudioHandler: Audio source set, currentIndex=${_player.currentIndex}, processingState=${_player.processingState}');
          }
          
          // Устанавливаем текущий mediaItem
          if (clampedIndex >= 0 && clampedIndex < mediaItems.length) {
            mediaItem.value = mediaItems[clampedIndex];
            if (kDebugMode) {
              debugPrint('KConnectAudioHandler: MediaItem set to: ${mediaItems[clampedIndex].title}');
            }
          }
          
          // Запускаем воспроизведение только если autoPlay=true
          if (autoPlay) {
            if (kDebugMode) {
              debugPrint('KConnectAudioHandler: autoPlay=true, calling _player.play()');
            }
            await _player.play();
            if (kDebugMode) {
              debugPrint('KConnectAudioHandler: Queue updated - ${mediaItems.length} tracks, currentIndex=$clampedIndex, autoPlay=true, playing started');
              debugPrint('KConnectAudioHandler: Player state after play - playing=${_player.playing}, processingState=${_player.processingState}');
            }
          } else {
            if (kDebugMode) {
              debugPrint('KConnectAudioHandler: Queue updated - ${mediaItems.length} tracks, currentIndex=$clampedIndex, autoPlay=false');
            }
          }
        } else {
          if (kDebugMode) {
            debugPrint('KConnectAudioHandler: updateQueue - mediaItemsData is null or empty');
          }
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('KConnectAudioHandler: Error updating queue: $e');
          debugPrint('KConnectAudioHandler: Stack trace: $stackTrace');
        }
      }
    }
  }

  void setOnSkipCallback(OnSkipCallback? callback) {
    if (kDebugMode) {
      debugPrint('KConnectAudioHandler: setOnSkipCallback called, callback is ${callback != null ? "set" : "null"}');
    }
    _onSkipCallback = callback;
    _SkipCallbackService.setCallback(callback);
  }

  void updateCommandAvailability({
    required bool canSkipNext,
    required bool canSkipPrevious,
  }) {
    // Этот метод больше не используется активно, так как флаги вычисляются динамически
    // Оставлено для обратной совместимости
    if (kDebugMode) {
      debugPrint('KConnectAudioHandler: updateCommandAvailability - flags are now computed dynamically, ignoring');
    }
    // Обновляем PlaybackState, чтобы кнопки обновились
    final updatedState = _transformEvent(_player.playbackEvent);
    playbackState.add(updatedState);
  }

  void updateLikeState(bool isLiked) {
    if (mediaItem.value != null) {
      final currentItem = mediaItem.value!;
      mediaItem.value = currentItem.copyWith(
        extras: {
          ...?currentItem.extras,
          'isLiked': isLiked,
        },
      );
    }
  }

  /// Строит индексы для компактного уведомления Android
  List<int>? _buildAndroidCompactActionIndices(List<MediaControl> controls, bool canSkipPrevious, bool canSkipNext) {
    if (controls.isEmpty) return null;
    
    final indices = <int>[];
    // Previous button
    if (canSkipPrevious) indices.add(0);
    // Play/Pause button
    indices.add(canSkipPrevious ? 1 : 0);
    // Next button
    if (canSkipNext) indices.add(canSkipPrevious ? 2 : 1);
    
    return indices.isEmpty ? null : indices;
  }

  /// Трансформирует события just_audio в PlaybackState для audio_service
  PlaybackState _transformEvent(PlaybackEvent event) {
    // Используем currentIndex из player, так как он более точный
    // event.currentIndex может быть null или устаревшим
    final currentIndex = _player.currentIndex ?? event.currentIndex ?? 0;
    final queueLength = queue.value.length;
    final canSkipNext = currentIndex < queueLength - 1;
    final canSkipPrevious = currentIndex > 0;
    
    // Если очередь состоит из одного трека, всегда показываем кнопки skip
    // (они будут работать через callback для загрузки следующей страницы)
    final showSkipNext = canSkipNext || queueLength == 1;
    final showSkipPrevious = canSkipPrevious || queueLength == 1;
    
    final controls = <MediaControl>[];
    if (showSkipPrevious) {
      controls.add(MediaControl.skipToPrevious);
    }
    controls.add(_player.playing ? MediaControl.pause : MediaControl.play);
    if (showSkipNext) {
      controls.add(MediaControl.skipToNext);
    }

    return PlaybackState(
      controls: controls,
      systemActions: {
        MediaAction.seek,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: _buildAndroidCompactActionIndices(controls, showSkipPrevious, showSkipNext),
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: currentIndex, // Используем currentIndex из player вместо event.currentIndex
    );
  }
}
