import 'package:flutter/foundation.dart';
import 'package:audio_service/audio_service.dart';
import 'kconnect_audio_handler.dart';

/// Централизованный сервис для управления жизненным циклом AudioService
/// 
/// Отвечает за:
/// - Инициализацию AudioService в правильное время
/// - Проверку готовности сервиса
/// - Предоставление доступа к AudioHandler
/// - Обработку ошибок инициализации с повторными попытками
class AudioServiceManager {
  static bool _isServiceReady = false;
  static bool _isInitializing = false;
  static bool _builderWasCalled = false; // Флаг для проверки, вызывался ли builder
  static AudioHandler? _handler; // Сохраняем ссылку на handler
  
  /// Инициализация AudioService
  /// 
  /// Создает KConnectAudioHandler и инициализирует AudioService.
  /// Должен вызываться в main() после WidgetsFlutterBinding.ensureInitialized()
  static Future<void> init() async {
    if (_isServiceReady) {
      if (kDebugMode) {
        debugPrint('AudioServiceManager: Service already initialized');
      }
      return;
    }
    
    if (_isInitializing) {
      if (kDebugMode) {
        debugPrint('AudioServiceManager: Initialization already in progress');
      }
      return;
    }
    
    _isInitializing = true;
    
    try {
      // Ждем немного, чтобы FlutterEngine был готов
      // Это особенно важно для Android
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (kDebugMode) {
        debugPrint('AudioServiceManager: Initializing AudioService...');
      }
      
      // Инициализируем AudioService
      // ВАЖНО: Handler должен быть создан ВНУТРИ builder, потому что builder
      // вызывается в отдельном isolate audio_service, и статические переменные
      // не разделяются между изолятами
      _handler = await AudioService.init(
        builder: () {
          _builderWasCalled = true; // Отмечаем, что builder был вызван
          
          if (kDebugMode) {
            debugPrint('AudioServiceManager: ========== AudioService builder called ==========');
            debugPrint('AudioServiceManager: Builder called in audio_service isolate');
            debugPrint('AudioServiceManager: Creating handler in audio_service isolate...');
          }
          
          // Создаем handler в изоляте audio_service
          // Это единственный способ гарантировать, что handler работает в правильном изоляте
          final handler = KConnectAudioHandler();
          
          if (kDebugMode) {
            debugPrint('AudioServiceManager: Handler created successfully in isolate');
            debugPrint('AudioServiceManager: Handler instance: ${handler.hashCode}');
            debugPrint('AudioServiceManager: Handler type: ${handler.runtimeType}');
            debugPrint('AudioServiceManager: Returning handler to audio_service');
          }
          
          return handler;
        },
        config: AudioServiceConfig(
          androidNotificationChannelId: 'com.example.kconnectMobile.audio',
          androidNotificationChannelName: 'K-Connect Music',
          androidNotificationChannelDescription: 'Music playback controls',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidShowNotificationBadge: false,
        ),
      );
      
      _isServiceReady = true;
      
      if (kDebugMode) {
        debugPrint('AudioServiceManager: AudioService initialized successfully');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('AudioServiceManager: Error initializing AudioService: $e');
        debugPrint('AudioServiceManager: Stack trace: $stackTrace');
      }
      
      // Если ошибка связана с тем, что AudioService уже инициализирован,
      // проверяем, вызывался ли builder
      if (e.toString().contains('_cacheManager') || 
          e.toString().contains('already initialized')) {
        if (kDebugMode) {
          debugPrint('AudioServiceManager: AudioService appears to be already initialized');
          debugPrint('AudioServiceManager: Builder was called: $_builderWasCalled');
        }
        
        // Если builder был вызван, значит handler создан и сервис готов
        // Если builder не был вызван, значит AudioService был инициализирован ранее
        // и handler может быть не создан - в этом случае не помечаем как готовый
        if (_builderWasCalled) {
          if (kDebugMode) {
            debugPrint('AudioServiceManager: Builder was called, marking as ready');
          }
          _isServiceReady = true;
        } else {
          if (kDebugMode) {
            debugPrint('AudioServiceManager: WARNING - Builder was NOT called, but AudioService is already initialized');
            debugPrint('AudioServiceManager: This may indicate that handler is not created. Will not mark as ready.');
          }
          // Не помечаем как готовый, чтобы можно было попробовать снова
        }
      } else {
        // Для других ошибок (например, FlutterEngine) не помечаем как готовый
        // чтобы можно было попробовать снова через ensureServiceReady()
        if (kDebugMode) {
          debugPrint('AudioServiceManager: AudioService init failed, will not mark as ready');
        }
      }
    } finally {
      _isInitializing = false;
    }
  }
  
  /// Проверка готовности сервиса
  /// 
  /// Возвращает true, если AudioService успешно инициализирован
  static bool isServiceReady() {
    return _isServiceReady;
  }
  
  /// Гарантия готовности сервиса с повторными попытками
  /// 
  /// Если сервис не готов, пытается инициализировать его с повторными попытками.
  /// Используется перед критическими операциями (playTrack, customAction и т.д.)
  static Future<bool> ensureServiceReady({int maxRetries = 3, Duration retryDelay = const Duration(seconds: 2)}) async {
    if (_isServiceReady) {
      return true;
    }
    
    if (kDebugMode) {
      debugPrint('AudioServiceManager: Service not ready, attempting to initialize...');
    }
    
    for (int i = 0; i < maxRetries; i++) {
      try {
        await init();
        
        if (_isServiceReady) {
          if (kDebugMode) {
            debugPrint('AudioServiceManager: Service ready after ${i + 1} attempt(s)');
          }
          return true;
        }
        
        if (i < maxRetries - 1) {
          if (kDebugMode) {
            debugPrint('AudioServiceManager: Retry ${i + 2}/$maxRetries in ${retryDelay.inSeconds} seconds...');
          }
          await Future.delayed(retryDelay);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('AudioServiceManager: Error in ensureServiceReady (attempt ${i + 1}/$maxRetries): $e');
        }
        
        if (i < maxRetries - 1) {
          await Future.delayed(retryDelay);
        }
      }
    }
    
    if (kDebugMode) {
      debugPrint('AudioServiceManager: Failed to ensure service ready after $maxRetries attempts');
    }
    
    return false;
  }
  
  /// Получение AudioHandler
  /// 
  /// Возвращает proxy handler, который можно использовать для вызова методов
  /// Handler находится в другом isolate, но AudioService предоставляет proxy
  static AudioHandler? getHandler() {
    return _handler;
  }
  
  /// Сброс состояния (для тестирования или переинициализации)
  static void reset() {
    _isServiceReady = false;
    _isInitializing = false;
    _builderWasCalled = false;
    _handler = null;
  }
  
  /// Проверка, вызывался ли builder
  static bool wasBuilderCalled() {
    return _builderWasCalled;
  }
}

