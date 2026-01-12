/// BLoC для управления воспроизведением музыки
/// Простой слушатель AudioService - трансформирует состояние в доменную модель
library;

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:audio_service/audio_service.dart' hide PlaybackState;
import 'package:audio_service/audio_service.dart' as audio_service show PlaybackState;
import '../../domain/repositories/audio_repository.dart';
import '../../domain/usecases/play_track_usecase.dart';
import '../../domain/usecases/pause_usecase.dart';
import '../../domain/usecases/seek_usecase.dart';
import '../../domain/usecases/resume_usecase.dart';
import '../../domain/models/playback_state.dart';
import '../../domain/models/track.dart';
import '../../../../services/audio_service_manager.dart';

part 'playback_event.dart';

/// BLoC - просто слушает AudioService и эмитит состояние
class PlaybackBloc extends Bloc<PlaybackEvent, PlaybackState> {
  final AudioRepository _audioRepository;
  final PlayTrackUseCase _playTrackUseCase;
  final PauseUseCase _pauseUseCase;
  final SeekUseCase _seekUseCase;
  final ResumeUseCase _resumeUseCase;
  
  StreamSubscription<audio_service.PlaybackState>? _audioServiceSubscription;
  StreamSubscription<MediaItem?>? _mediaItemSubscription;

  PlaybackBloc({
    required AudioRepository audioRepository,
    required PlayTrackUseCase playTrackUseCase,
    required PauseUseCase pauseUseCase,
    required SeekUseCase seekUseCase,
    required ResumeUseCase resumeUseCase,
  }) : _audioRepository = audioRepository,
       _playTrackUseCase = playTrackUseCase,
       _pauseUseCase = pauseUseCase,
       _seekUseCase = seekUseCase,
       _resumeUseCase = resumeUseCase,
       super(const PlaybackState()) {
    on<PlaybackPlayRequested>(_onPlayRequested);
    on<PlaybackPauseRequested>(_onPauseRequested);
    on<PlaybackResumeRequested>(_onResumeRequested);
    on<PlaybackStopRequested>(_onStopRequested);
    on<PlaybackSeekRequested>(_onSeekRequested);
    on<PlaybackToggleRequested>(_onToggleRequested);
    on<PlaybackStateUpdated>(_onStateUpdated);
    on<PlaybackQueueChanged>(_onQueueChanged);

    _setupAudioServiceSubscription();
  }
  
  void _setupAudioServiceSubscription() {
    if (!AudioServiceManager.isServiceReady()) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _setupAudioServiceSubscription();
      });
      return;
    }

    final handler = AudioServiceManager.getHandler();
    if (handler != null) {
      // Подписка на playbackState
      _audioServiceSubscription = handler.playbackState.listen(
        (audioState) {
          final newState = _createStateFromAudioService(audioState);
          add(PlaybackStateUpdated(newState));
        },
      );

      // Подписка на mediaItem
      _mediaItemSubscription = handler.mediaItem.listen(
        (mediaItem) {
          if (mediaItem == null) {
            if (state.hasTrack) {
              add(PlaybackStateUpdated(const PlaybackState()));
            }
          } else {
            final newState = _createStateFromMediaItem(mediaItem);
            add(PlaybackStateUpdated(newState));
          }
        },
      );

      // Синхронизация начального состояния
      final initialPlaybackState = handler.playbackState.valueOrNull;
      if (initialPlaybackState != null) {
        add(PlaybackStateUpdated(_createStateFromAudioService(initialPlaybackState)));
      }
      final initialMediaItem = handler.mediaItem.valueOrNull;
      if (initialMediaItem != null) {
        add(PlaybackStateUpdated(_createStateFromMediaItem(initialMediaItem)));
      }
    }
  }

  PlaybackState _createStateFromAudioService(audio_service.PlaybackState audioState) {
    final handler = AudioServiceManager.getHandler();
    final mediaItem = handler?.mediaItem.valueOrNull;
    if (mediaItem == null) {
      return const PlaybackState();
    }

    final track = _trackFromMediaItem(mediaItem);
    if (track == null) {
      return const PlaybackState();
    }

    final status = _mapStatus(audioState);

    return PlaybackState(
      currentTrack: track,
      status: status,
      position: audioState.position,
      duration: mediaItem.duration,
      isBuffering: audioState.processingState == AudioProcessingState.buffering,
      lastUpdated: DateTime.now(),
    );
  }

  PlaybackState _createStateFromMediaItem(MediaItem mediaItem) {
    final track = _trackFromMediaItem(mediaItem);
    if (track == null) {
      return const PlaybackState();
    }

    final handler = AudioServiceManager.getHandler();
    final audioState = handler?.playbackState.valueOrNull;

    if (audioState == null) {
      return PlaybackState(
        currentTrack: track,
        duration: mediaItem.duration,
        position: state.position,
        status: state.status,
        isBuffering: state.isBuffering,
        lastUpdated: DateTime.now(),
      );
    }

    final status = _mapStatus(audioState);

    return PlaybackState(
      currentTrack: track,
      status: status,
      position: audioState.position,
      duration: mediaItem.duration,
      isBuffering: audioState.processingState == AudioProcessingState.buffering,
      lastUpdated: DateTime.now(),
    );
  }

  Track? _trackFromMediaItem(MediaItem mediaItem) {
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
  }

  PlaybackStatus _mapStatus(audio_service.PlaybackState audioState) {
    if (audioState.playing) {
      return PlaybackStatus.playing;
    }
    switch (audioState.processingState) {
      case AudioProcessingState.buffering:
        return PlaybackStatus.buffering;
      case AudioProcessingState.ready:
        return PlaybackStatus.paused;
      default:
        return PlaybackStatus.stopped;
    }
  }

  void _onPlayRequested(PlaybackPlayRequested event, Emitter<PlaybackState> emit) async {
    try {
      emit(state.copyWith(
        currentTrack: event.track,
        status: PlaybackStatus.buffering,
        error: null,
      ));
      await _playTrackUseCase.call(event.track);
    } catch (e) {
      emit(state.copyWith(
        status: PlaybackStatus.stopped,
        error: e.toString(),
      ));
    }
  }

  void _onPauseRequested(PlaybackPauseRequested event, Emitter<PlaybackState> emit) async {
    try {
      await _pauseUseCase.call();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onResumeRequested(PlaybackResumeRequested event, Emitter<PlaybackState> emit) async {
    try {
      await _resumeUseCase.call();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onStopRequested(PlaybackStopRequested event, Emitter<PlaybackState> emit) async {
    try {
      await _audioRepository.stop();
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onSeekRequested(PlaybackSeekRequested event, Emitter<PlaybackState> emit) async {
    try {
      await _seekUseCase.call(event.position);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onToggleRequested(PlaybackToggleRequested event, Emitter<PlaybackState> emit) async {
    if (!state.hasTrack) return;
    
    if (state.isPlaying) {
      await _pauseUseCase.call();
    } else {
      await _resumeUseCase.call();
    }
  }

  void _onStateUpdated(PlaybackStateUpdated event, Emitter<PlaybackState> emit) {
    if (event.newState.error == 'COMPLETED' && event.newState.currentTrack != null) {
      // Трек завершен - можно перейти к следующему
    }
    emit(event.newState.copyWith(lastUpdated: DateTime.now()));
  }

  void _onQueueChanged(PlaybackQueueChanged event, Emitter<PlaybackState> emit) {
    add(PlaybackPlayRequested(event.currentTrack));
  }

  @override
  Future<void> close() {
    _audioServiceSubscription?.cancel();
    _mediaItemSubscription?.cancel();
    return super.close();
  }
}
