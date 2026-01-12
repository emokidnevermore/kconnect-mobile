/// Use case для воспроизведения музыкального трека
///
/// Отвечает за бизнес-логику начала воспроизведения трека.
/// Определяет, нужно ли начать новый трек или возобновить текущий.
/// Инкапсулирует логику выбора действия воспроизведения.
library;

import 'dart:developer' as developer;
import '../repositories/audio_repository.dart';
import '../repositories/music_repository.dart';
import '../models/track.dart';

/// Use case для выполнения воспроизведения трека
///
/// Принимает трек для воспроизведения, определяет текущее состояние плеера
/// и выполняет соответствующее действие: начало нового трека или возобновление.
/// Возвращает результат операции воспроизведения.
class PlayTrackUseCase {
  final AudioRepository _audioRepository;

  PlayTrackUseCase(this._audioRepository, MusicRepository _);

  Future<void> call(Track track) async {
    try {
      developer.log('PlayTrackUseCase: Starting play for ${track.title}', name: 'USECASE');
      await _audioRepository.playTrack(track);
      developer.log('PlayTrackUseCase: playTrack completed', name: 'USECASE');
    } catch (e, stackTrace) {
      developer.log('PlayTrackUseCase: Error playing track ${track.title}', name: 'USECASE', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
