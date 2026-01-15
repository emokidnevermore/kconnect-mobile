/// Менеджер состояния медиа для навигационной панели
///
/// Управляет стримами состояния медиа-плеера и предоставляет
/// унифицированный интерфейс для компонентов навигации
library;

import 'package:audio_service/audio_service.dart';
import 'package:rxdart/rxdart.dart';
import '../../services/audio_service_manager.dart';
import '../../features/music/domain/models/track.dart';

/// Менеджер состояния медиа
class MediaStateManager {
  /// Стрим состояния медиа
  late final Stream<({bool hasTrack, bool playing, double progress, bool isBuffering})> mediaStateStream;

  /// Стрим текущего трека
  late final Stream<Track?> trackStream;

  MediaStateManager() {
    _initializeStreams();
  }

  void _initializeStreams() {
    // Инициализируем стримы в конструкторе
    mediaStateStream = _createMediaStateStream().asBroadcastStream();
    trackStream = _createTrackStream().asBroadcastStream();
  }

  /// Создать поток состояния медиа
  Stream<({bool hasTrack, bool playing, double progress, bool isBuffering})> _createMediaStateStream() {
    final handler = AudioServiceManager.getHandler();

    Stream<MediaItem?> mediaItemStream;
    if (handler != null) {
      final initialMediaItem = handler.mediaItem.valueOrNull;
      mediaItemStream = handler.mediaItem.startWith(initialMediaItem);
    } else {
      mediaItemStream = Stream.value(null);
    }

    Stream<bool> playingStream;
    Stream<bool> bufferingStream;
    if (handler != null) {
      final initialPlaybackState = handler.playbackState.valueOrNull;
      final initialPlaying = initialPlaybackState?.playing ?? false;
      final initialBuffering = initialPlaybackState?.processingState == AudioProcessingState.buffering;

      playingStream = handler.playbackState
          .map((state) => state.playing)
          .distinct()
          .startWith(initialPlaying);

      bufferingStream = handler.playbackState
          .map((state) => state.processingState == AudioProcessingState.buffering)
          .distinct()
          .startWith(initialBuffering);
    } else {
      playingStream = Stream.value(false);
      bufferingStream = Stream.value(false);
    }

    return Rx.combineLatest4<MediaItem?, bool, Duration, bool, ({bool hasTrack, bool playing, double progress, bool isBuffering})>(
      mediaItemStream,
      playingStream,
      AudioService.position.startWith(Duration.zero),
      bufferingStream,
      (mediaItem, playing, position, isBuffering) {
        final duration = mediaItem?.duration;
        final progress = (duration != null && duration.inSeconds > 0)
            ? position.inSeconds / duration.inSeconds
            : 0.0;
        final hasTrack = mediaItem != null;
        return (hasTrack: hasTrack, playing: playing, progress: progress, isBuffering: isBuffering);
      },
    );
  }

  /// Создать поток трека
  Stream<Track?> _createTrackStream() {
    final handler = AudioServiceManager.getHandler();

    if (handler != null) {
      return handler.mediaItem.map((mediaItem) {
        if (mediaItem == null) return null;
        final trackId = mediaItem.extras?['trackId'] as int?;
        if (trackId == null) return null;
        return Track(
          id: trackId,
          title: mediaItem.title,
          artist: mediaItem.artist ?? '',
          durationMs: mediaItem.duration?.inMilliseconds ?? 0,
          coverPath: mediaItem.extras?['coverPath'] as String?,
          filePath: mediaItem.extras?['originalUrl'] as String? ?? mediaItem.id,
          isLiked: mediaItem.extras?['isLiked'] as bool? ?? false,
        );
      }).startWith(null);
    }

    return Stream.value(null);
  }

  /// Создать комбинированный стрим для компонентов
  Stream<({bool hasTrack, bool playing, double progress, Track? track, bool isBuffering})> get combinedStream {
    return Rx.combineLatest3<({bool hasTrack, bool playing, double progress, bool isBuffering}), Track?, Duration,
        ({bool hasTrack, bool playing, double progress, Track? track, bool isBuffering})>(
      mediaStateStream,
      trackStream,
      AudioService.position,
      (mediaState, track, position) => (
        hasTrack: mediaState.hasTrack,
        playing: mediaState.playing,
        progress: mediaState.progress,
        track: track,
        isBuffering: mediaState.isBuffering
      ),
    ).asBroadcastStream();
  }
}
