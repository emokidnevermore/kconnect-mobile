import 'package:kconnect_mobile/features/music/domain/models/track.dart';

/// Репозиторий для управления аудио воспроизведением
///
/// Определяет интерфейс для работы с аудио плеером.
/// Является простым прокси для команд управления воспроизведением.
/// Состояние воспроизведения получается напрямую из AudioService стримов в PlaybackBloc.
abstract class AudioRepository {
  // Playback control commands
  Future<void> playTrack(Track track);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> seek(Duration position);

  // Lifecycle
  void dispose();
}
