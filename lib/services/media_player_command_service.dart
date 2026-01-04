import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../features/music/presentation/blocs/queue_bloc.dart';
import '../features/music/presentation/blocs/queue_event.dart';
import '../features/music/presentation/blocs/playback_bloc.dart';

class MediaPlayerCommandService {
  static const MethodChannel _channel = MethodChannel('com.example.kconnectMobile/audio');
  static QueueBloc? _queueBloc;
  static PlaybackBloc? _playbackBloc;

  static void initialize({
    required QueueBloc queueBloc,
    required PlaybackBloc playbackBloc,
    required dynamic audioRepository,
  }) {
    _queueBloc = queueBloc;
    _playbackBloc = playbackBloc;
    _setupMethodChannel();
    _setupQueueListener();
  }
  
  static void _setupQueueListener() {
    _queueBloc?.stream.listen((state) {
      updateRemoteCommandAvailability(
        canGoNext: state.canGoNext,
        canGoPrevious: state.canGoPrevious,
      );
    });
  }

  static void _setupMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'handleNextTrack':
          if (_queueBloc != null && _playbackBloc != null) {
            final state = _queueBloc!.state;
            if (state.canGoNext) {
              _queueBloc!.add(const QueueNextRequested());
              Future.delayed(const Duration(milliseconds: 200), () {
                final newState = _queueBloc!.state;
                if (newState.currentTrack != null) {
                  _playbackBloc!.add(PlaybackPlayRequested(newState.currentTrack!));
                }
              });
            }
          }
          break;
        case 'handlePreviousTrack':
          if (_queueBloc != null && _playbackBloc != null) {
            final state = _queueBloc!.state;
            if (state.canGoPrevious) {
              _queueBloc!.add(const QueuePreviousRequested());
              Future.delayed(const Duration(milliseconds: 200), () {
                final newState = _queueBloc!.state;
                if (newState.currentTrack != null) {
                  _playbackBloc!.add(PlaybackPlayRequested(newState.currentTrack!));
                }
              });
            }
          }
          break;
      }
    });
  }

  static Future<void> updateRemoteCommandAvailability({
    required bool canGoNext,
    required bool canGoPrevious,
  }) async {
    try {
      await _channel.invokeMethod('updateCommandAvailability', {
        'canGoNext': canGoNext,
        'canGoPrevious': canGoPrevious,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to update command availability: $e');
    }
  }
}

