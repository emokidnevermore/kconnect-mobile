import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import '../features/music/presentation/blocs/queue_bloc.dart';
import '../features/music/presentation/blocs/queue_event.dart';
import '../features/music/domain/models/queue_state.dart';
import 'audio_service_manager.dart';
import 'kconnect_audio_handler.dart';
import 'cache/audio_preload_service.dart';

/// Простой сервис-мост между QueueBloc и audio_service
///
/// Синхронизирует состояние очереди из QueueBloc с audio_service.
/// Один источник истины - QueueBloc.
class MediaPlayerService {
  static QueueBloc? _queueBloc;
  static OnSkipCallback? _skipCallback;
  static bool _isInitialized = false;
  static bool _isSwitchingTrack = false; // Флаг для предотвращения рекурсивных вызовов

  /// Инициализация сервиса
  static void initialize(QueueBloc queueBloc) {
    if (_isInitialized) {
      if (kDebugMode) {
        debugPrint('MediaPlayerService: Already initialized, skipping');
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('MediaPlayerService: Initializing...');
    }
    _queueBloc = queueBloc;
    
    _setupSkipCallback();
    _setupQueueListener();
    
    _isInitialized = true;
    
    if (kDebugMode) {
      debugPrint('MediaPlayerService: Initialization completed');
    }
  }

  /// Настройка слушателя изменений QueueBloc
  static void _setupQueueListener() {
    if (_queueBloc == null) return;

    // Синхронизируем начальное состояние, если очередь уже есть
    final currentState = _queueBloc!.state;
    if (currentState.hasQueue && currentState.currentQueue != null) {
      if (kDebugMode) {
        debugPrint('MediaPlayerService: Initial queue state - ${currentState.totalTracks} tracks, syncing...');
      }
      _onQueueCreated(currentState);
    }

    // Настраиваем слушатель изменений currentIndex из AudioHandler
    _setupCurrentIndexListener();

    // Отслеживаем предыдущее состояние для определения изменений
    QueueState? previousState;

    // Слушаем изменения состояния
    _queueBloc!.stream.listen((state) {
      if (kDebugMode) {
        debugPrint('MediaPlayerService: Queue state changed - hasQueue=${state.hasQueue}, totalTracks=${state.totalTracks}, currentIndex=${state.currentIndex}');
      }

      // Определяем тип изменения
      final isNewQueue = previousState == null || !previousState!.hasQueue;
      
      // Проверяем, что это действительно новая очередь (другой контекст или другие треки)
      final prevQueue = previousState?.currentQueue;
      final currQueue = state.currentQueue;
      final isDifferentQueue = previousState != null &&
          previousState!.hasQueue &&
          state.hasQueue &&
          prevQueue != null &&
          currQueue != null &&
          (prevQueue.context != currQueue.context ||
           prevQueue.items.length != currQueue.items.length ||
           !prevQueue.items.every((item) => 
             currQueue.items.any((newItem) => newItem.track.id == item.track.id)));
      
      final indexChanged = previousState != null &&
          previousState!.hasQueue &&
          state.hasQueue &&
          !isDifferentQueue &&
          previousState!.currentIndex != state.currentIndex;
      final queueGrew = previousState != null &&
          previousState!.hasQueue &&
          state.hasQueue &&
          !isDifferentQueue &&
          state.totalTracks > previousState!.totalTracks;

      if (state.hasQueue && state.currentQueue != null) {
        if (isNewQueue || isDifferentQueue) {
          // Новая очередь создана или очередь изменилась - передаем весь список в audio_service
          if (kDebugMode) {
            debugPrint('MediaPlayerService: New queue created or queue changed, syncing to audio_service (isNewQueue=$isNewQueue, isDifferentQueue=$isDifferentQueue)');
          }
          _onQueueCreated(state);
        } else if (queueGrew) {
          // Очередь выросла - обновляем в audio_service
          if (kDebugMode) {
            debugPrint('MediaPlayerService: Queue grew, updating audio_service');
          }
          _onQueueGrew(state);
        } else if (indexChanged) {
          // Индекс изменился - переключаем трек
          if (kDebugMode) {
            debugPrint('MediaPlayerService: Index changed from ${previousState!.currentIndex} to ${state.currentIndex}');
          }
          _onIndexChanged(state);
        }
      }

      previousState = state;

      // Обновляем доступность команд для системного плеера
      _updateCommandAvailability(state);
    });
  }

  /// Обработка создания новой очереди
  static void _onQueueCreated(QueueState state) async {
    if (state.currentQueue == null) return;

    try {
      // Предзагружаем треки из очереди
      _preloadQueueTracks(state);

      // Убеждаемся, что AudioService готов
      await AudioServiceManager.ensureServiceReady();

      // Преобразуем треки в MediaItem
      final mediaItems = state.currentQueue!.items.map((item) {
        final track = item.track;
        final fullUrl = track.filePath.startsWith('http')
            ? track.filePath
            : 'https://k-connect.ru${track.filePath}';
        final coverUrl = track.coverPath != null
            ? (track.coverPath!.startsWith('http')
                ? track.coverPath!
                : 'https://k-connect.ru${track.coverPath!}')
            : null;

        return MediaItem(
          id: fullUrl,
          title: track.title,
          artist: track.artist,
          duration: Duration(milliseconds: track.durationMs),
          artUri: coverUrl != null ? Uri.parse(coverUrl) : null,
          extras: {
            'trackId': track.id,
            'coverPath': track.coverPath,
            'isLiked': track.isLiked,
          },
        );
      }).toList();

      // Используем прямой вызов метода handler для надежности
      final handler = AudioServiceManager.getHandler();
      if (handler is KConnectAudioHandler) {
        if (kDebugMode) {
          debugPrint('MediaPlayerService: Using direct handler method updateQueueDirectly with ${mediaItems.length} tracks, currentIndex=${state.currentIndex}');
        }
        
        // Вызываем метод напрямую
        await handler.updateQueueDirectly(
          mediaItems: mediaItems,
          currentIndex: state.currentIndex,
          autoPlay: true,
        );
        
        if (kDebugMode) {
          debugPrint('MediaPlayerService: Queue synced via direct handler method - ${mediaItems.length} tracks, currentIndex=${state.currentIndex}');
        }
      } else {
        // Fallback на customAction
        if (kDebugMode) {
          debugPrint('MediaPlayerService: Handler not KConnectAudioHandler, using AudioService.customAction');
        }
        
        await handler?.customAction('updateQueue', {
          'mediaItems': mediaItems.map((item) => <String, dynamic>{
            'id': item.id,
            'title': item.title,
            'artist': item.artist,
            'duration': item.duration?.inMilliseconds,
            'artUri': item.artUri?.toString(),
            'extras': item.extras,
          }).toList(),
          'currentIndex': state.currentIndex,
          'autoPlay': true,
        });
        
        if (kDebugMode) {
          debugPrint('MediaPlayerService: Queue synced via AudioService.customAction - ${mediaItems.length} tracks, currentIndex=${state.currentIndex}');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('MediaPlayerService: Error syncing queue to audio_service: $e');
        debugPrint('MediaPlayerService: Stack trace: $stackTrace');
      }
    }
  }

  /// Обработка роста очереди (добавление треков)
  static void _onQueueGrew(QueueState state) {
    // При росте очереди просто обновляем её полностью
    _onQueueCreated(state);
  }

  /// Обработка изменения индекса (переключение трека)
  static void _onIndexChanged(QueueState state) {
    final handler = AudioServiceManager.getHandler();
    if (handler != null && state.currentIndex >= 0 && state.currentIndex < state.totalTracks) {
      if (kDebugMode) {
        debugPrint('MediaPlayerService: Switching to track at index ${state.currentIndex}');
      }

      // Устанавливаем флаг чтобы предотвратить рекурсивные вызовы
      _isSwitchingTrack = true;

      handler.skipToQueueItem(state.currentIndex);

      // Сбрасываем флаг после небольшой задержки
      Future.delayed(const Duration(milliseconds: 100), () {
        _isSwitchingTrack = false;
      });

      // Предзагружаем следующий и предыдущий треки
      _preloadQueueTracks(state);
    }
  }

  /// Предзагружает треки из очереди
  static void _preloadQueueTracks(QueueState state) {
    if (state.currentQueue == null) return;

    final preloadService = AudioPreloadService.instance;
    final queueTracks = state.currentQueue!.items.map((item) => item.track).toList();
    final currentTrack = state.currentTrack;

    preloadService.preloadNextTrackInQueue(
      currentTrack,
      queueTracks,
      state.currentIndex,
    );
  }

  /// Настройка callback для системного плеера
  static void _setupSkipCallback() {
    final handler = AudioServiceManager.getHandler();
    if (handler == null) {
      if (kDebugMode) {
        debugPrint('MediaPlayerService: Handler not available, will set callback later');
      }
      // Попробуем установить callback позже
      Future.delayed(const Duration(milliseconds: 500), () {
        _setupSkipCallback();
      });
      return;
    }

    if (handler is KConnectAudioHandler) {
      _skipCallback = (isNext) {
        if (kDebugMode) {
          debugPrint('MediaPlayerService: Skip callback invoked with isNext=$isNext');
        }
        if (_queueBloc != null) {
          if (isNext) {
            _queueBloc!.add(const QueueNextRequested());
          } else {
            _queueBloc!.add(const QueuePreviousRequested());
          }
        }
      };

      handler.setOnSkipCallback(_skipCallback);
      if (kDebugMode) {
        debugPrint('MediaPlayerService: Skip callback set successfully');
      }
    }
  }

  /// Настройка слушателя изменений currentIndex из AudioHandler
  static void _setupCurrentIndexListener() {
    final handler = AudioServiceManager.getHandler();
    if (handler == null || _queueBloc == null) {
      if (kDebugMode) {
        debugPrint('MediaPlayerService: Handler or QueueBloc not available for currentIndex listener');
      }
      return;
    }

    if (handler is KConnectAudioHandler) {
      // Слушаем изменения текущего индекса в just_audio
      // При автоматическом переходе на следующий трек обновляем QueueBloc
      // Пропускаем если это результат ручного переключения (флаг _isSwitchingTrack)
      handler.currentIndexStream.listen((currentIndex) {
        if (_isSwitchingTrack) {
          if (kDebugMode) {
            debugPrint('MediaPlayerService: Skipping currentIndex change - manual switching in progress');
          }
          return;
        }

        if (currentIndex != null && _queueBloc != null) {
          final currentState = _queueBloc!.state;
          if (currentState.hasQueue &&
              currentIndex >= 0 &&
              currentIndex < currentState.totalTracks &&
              currentIndex != currentState.currentIndex) {
            if (kDebugMode) {
              debugPrint('MediaPlayerService: currentIndex changed to $currentIndex, notifying QueueBloc');
            }
            _queueBloc!.add(QueueIndexChanged(currentIndex));
          }
        }
      });

      if (kDebugMode) {
        debugPrint('MediaPlayerService: currentIndex listener set up successfully');
      }
    }
  }

  /// Обновление доступности команд для системного плеера
  static void _updateCommandAvailability(QueueState state) {
    final handler = AudioServiceManager.getHandler();
    if (handler is KConnectAudioHandler) {
      handler.updateCommandAvailability(
        canSkipNext: state.canGoNext,
        canSkipPrevious: state.canGoPrevious,
      );
    }
  }

  /// Обновляет статус лайка для трека во всех MediaItem'ах очереди
  ///
  /// Используется для синхронизации статуса лайка между MusicBloc и AudioService очередью.
  /// Когда трек лайкается/дизлайкается, нужно обновить соответствующий MediaItem в очереди,
  /// чтобы при переключении треков статус отображался корректно.
  static void updateTrackLikeStateInQueue(int trackId, bool isLiked) {
    final handler = AudioServiceManager.getHandler();
    if (handler is KConnectAudioHandler) {
      handler.updateTrackLikeStateInQueue(trackId, isLiked);
    } else {
      if (kDebugMode) {
        debugPrint('MediaPlayerService: Handler is not KConnectAudioHandler, cannot update queue like state');
      }
    }
  }
}
