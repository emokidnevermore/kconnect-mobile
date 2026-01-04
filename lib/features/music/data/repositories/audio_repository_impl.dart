library;

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/models/playback_state.dart';
import '../../domain/models/track.dart';
import 'package:just_audio/just_audio.dart';

class AudioRepositoryImpl implements AudioRepository {
  final AudioPlayer _audioPlayer;
  final StreamController<PlaybackState> _playbackStateController;
  PlaybackState _currentState;
  static const MethodChannel _channel = MethodChannel('com.example.kconnectMobile/audio');

  AudioRepositoryImpl()
      : _audioPlayer = AudioPlayer(),
        _playbackStateController = StreamController<PlaybackState>.broadcast(),
        _currentState = const PlaybackState() {
    _setupAudioPlayer();
    _setupMethodChannel();
  }
  
  void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'resume':
          await resume();
          break;
        case 'pause':
          await pause();
          break;
        case 'toggle':
          if (_audioPlayer.playing) {
            await pause();
          } else {
            await resume();
          }
          break;
        case 'nextTrack':
        case 'previousTrack':
          break;
        case 'seekForward':
          final seconds = (call.arguments as num?)?.toDouble() ?? 15.0;
          final currentPos = _audioPlayer.position;
          final duration = _audioPlayer.duration ?? Duration.zero;
          final newPosition = currentPos + Duration(seconds: seconds.toInt());
          final clampedPosition = newPosition > duration ? duration : newPosition;
          await seek(clampedPosition);
          break;
        case 'seekBackward':
          final seconds = (call.arguments as num?)?.toDouble() ?? 15.0;
          final currentPos = _audioPlayer.position;
          final duration = _audioPlayer.duration ?? Duration.zero;
          final newPosition = currentPos - Duration(seconds: seconds.toInt());
          final clampedPosition = newPosition < Duration.zero 
              ? Duration.zero 
              : (newPosition > duration ? duration : newPosition);
          await seek(clampedPosition);
          break;
        case 'seekTo':
          final milliseconds = (call.arguments as num?)?.toInt() ?? 0;
          final duration = _audioPlayer.duration;
          final targetPosition = Duration(milliseconds: milliseconds);
          final clampedPosition = duration != null && targetPosition > duration 
              ? duration 
              : (targetPosition < Duration.zero ? Duration.zero : targetPosition);
          await seek(clampedPosition);
          break;
      }
    });
  }

  void _setupAudioPlayer() {
    _audioPlayer.positionStream.listen((position) {
      _updateState(_currentState.copyWith(position: position));
      _updateNowPlayingInfo(position: position);
    });

    _audioPlayer.playerStateStream.listen((playerState) {
      PlaybackStatus status;
      bool isBuffering = false;

      switch (playerState.processingState) {
        case ProcessingState.idle:
        case ProcessingState.loading:
          status = PlaybackStatus.stopped;
          break;
        case ProcessingState.buffering:
          status = _audioPlayer.playing ? PlaybackStatus.playing : PlaybackStatus.stopped;
          isBuffering = true;
          break;
        case ProcessingState.ready:
          status = _audioPlayer.playing ? PlaybackStatus.playing : PlaybackStatus.paused;
          break;
        case ProcessingState.completed:
          status = PlaybackStatus.stopped;
          _updateState(_currentState.copyWith(position: Duration.zero));
          _playbackStateController.add(_currentState.copyWith(
            status: PlaybackStatus.stopped,
            error: 'COMPLETED',
          ));
          break;
      }

      _updateState(_currentState.copyWith(
        status: status,
        isBuffering: isBuffering,
        duration: _audioPlayer.duration,
      ));
      if (status == PlaybackStatus.playing || status == PlaybackStatus.paused) {
        _updateNowPlayingInfo();
      }
    });
  }

  void _updateState(PlaybackState newState) {
    _currentState = newState;
    _playbackStateController.add(newState);
  }

  @override
  Stream<PlaybackState> get playbackState => _playbackStateController.stream;

  @override
  PlaybackState get currentState => _currentState;

  @override
  Future<void> playTrack(Track track) async {
    try {
      await _audioPlayer.setUrl(_ensureFullUrl(track.filePath));
      _updateState(_currentState.copyWith(currentTrack: track));
      await _audioPlayer.play();
      _updateNowPlayingInfo(track: track);
    } catch (e) {
      _updateState(PlaybackState.error(track, e.toString()));
    }
  }
  
  void _updateNowPlayingInfo({Track? track, Duration? position}) {
    final currentTrack = track ?? _currentState.currentTrack;
    if (currentTrack == null) return;
    
    final currentPosition = position ?? _audioPlayer.position;
    final duration = _audioPlayer.duration ?? Duration(milliseconds: currentTrack.durationMs);
    
    try {
      _channel.invokeMethod('updateNowPlaying', {
        'title': currentTrack.title,
        'artist': currentTrack.artist,
        'duration': duration.inMilliseconds,
        'position': currentPosition.inMilliseconds,
        'isPlaying': _audioPlayer.playing,
        'artwork': currentTrack.coverPath != null 
            ? _ensureFullUrl(currentTrack.coverPath!)
            : null,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to update now playing info: $e');
    }
  }

  @override
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  @override
  Future<void> resume() async {
    await _audioPlayer.play();
  }

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    _updateState(const PlaybackState());
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  @override
  bool get isPlaying => _audioPlayer.playing;

  @override
  bool get isBuffering => _currentState.isBuffering;

  @override
  Duration get position => _audioPlayer.position;

  @override
  Duration? get duration => _audioPlayer.duration;

  String _ensureFullUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://k-connect.ru$url';
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _playbackStateController.close();
  }
}
