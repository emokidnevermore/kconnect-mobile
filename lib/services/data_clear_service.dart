/// Сервис для очистки кэшированных данных пользователя
///
/// Управляет очисткой всех пользовательских данных из BLoC состояний при выходе.
/// Гарантирует чистое состояние приложения для нового пользователя.
library;

import '../injection.dart';
import '../features/feed/presentation/blocs/feed_bloc.dart';
import '../features/feed/presentation/blocs/feed_event.dart';
import '../features/messages/presentation/blocs/messages_bloc.dart';
import '../features/messages/presentation/blocs/messages_event.dart';
import '../features/profile/presentation/blocs/profile_event.dart';
import '../features/profile/presentation/blocs/profile_bloc.dart';
import '../services/storage_service.dart';
import '../services/cache/global_cache_service.dart';
import '../services/cache/cache_category.dart';

/// Сервис очистки пользовательских данных
class DataClearService {
  const DataClearService();

  /// Очищает все кэшированные пользовательские данные из BLoC состояний
  /// Должен вызываться во время процесса выхода из аккаунта
  Future<void> clearAllUserData() async {
    final feedBloc = locator.get<FeedBloc>();
    final messagesBloc = locator.get<MessagesBloc>();
    final profileBloc = locator.get<ProfileBloc>();

    feedBloc.add(const InitFeedEvent());

    messagesBloc.add(InitMessagesEvent());

    profileBloc.add(ClearProfileCacheEvent());
    
    // Используем GlobalCacheService для очистки кэша изображений
    final cacheService = GlobalCacheService();
    await cacheService.clearCache([CacheCategory.images]);

    StorageService.clearPersonalizationSettings();
  }

  /// Очищает кэш при переключении аккаунтов (исключая персонализацию)
  /// Должно вызываться во время смены аккаунта
  Future<void> clearUserDataForAccountSwitch() async {
    final feedBloc = locator.get<FeedBloc>();
    final messagesBloc = locator.get<MessagesBloc>();
    final profileBloc = locator.get<ProfileBloc>();

    feedBloc.add(const InitFeedEvent());

    messagesBloc.add(InitMessagesEvent());

    profileBloc.add(ClearProfileCacheEvent());

    // Используем GlobalCacheService для очистки кэша изображений
    final cacheService = GlobalCacheService();
    await cacheService.clearCache([CacheCategory.images]);
  }
}
