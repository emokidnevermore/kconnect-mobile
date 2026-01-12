import 'package:flutter/material.dart';
import 'package:kconnect_mobile/app.dart';
import 'package:kconnect_mobile/injection.dart' show setupLocator;
import 'package:kconnect_mobile/services/audio_service_manager.dart';
import 'package:kconnect_mobile/services/storage_service.dart';

/// Точка входа в приложение K-Connect Mobile
///
/// Инициализирует зависимости, сервисы и запускает приложение.
/// Обеспечивает корректную последовательность инициализации компонентов.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация AudioServiceManager (должно быть до setupLocator)
  // чтобы AudioService был готов до создания репозиториев
  await AudioServiceManager.init();

  // Инициализация DI контейнера
  setupLocator();

  // Инициализация ValueNotifier для режима таб-бара
  await StorageService.initializeTabBarGlassMode();

  runApp(const KConnectApp());
}
