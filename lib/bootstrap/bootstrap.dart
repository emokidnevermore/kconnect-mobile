import 'package:audio_service/audio_service.dart';
import '../services/audio_service_manager.dart';

/// Bootstrap класс для обратной совместимости
/// 
/// Вся логика инициализации AudioService перенесена в AudioServiceManager.
/// Этот класс оставлен для обратной совместимости, если где-то используется
/// AppBootstrap.audioHandler
class AppBootstrap {
  /// Получение AudioHandler через AudioServiceManager
  static AudioHandler? get audioHandler => AudioServiceManager.getHandler();
}
