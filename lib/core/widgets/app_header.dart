/// Заголовок приложения с логотипом, названием и уведомлениями
///
/// Адаптивный заголовок, который изменяется в зависимости от текущего таба
/// и состояния приложения. Включает специальные заголовки для музыкальных секций
/// с кнопками возврата.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_text_styles.dart';
import '../../core/utils/theme_extensions.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/notifications/presentation/bloc/notifications_bloc.dart';
import '../../features/notifications/presentation/bloc/notifications_state.dart';
import 'badge_icon.dart';
import '../../services/storage_service.dart';

/// Виджет заголовка приложения
class AppHeader extends StatelessWidget {
  /// Индекс текущего активного таба
  final int currentTabIndex;

  /// Флаг нахождения в секции любимых треков музыки
  final bool isInMusicFavoritesSection;

  /// Колбэк для возврата из секции любимых треков
  final VoidCallback? onMusicFavoritesBack;

  /// Флаг нахождения в секции плейлистов музыки
  final bool isInMusicPlaylistsSection;

  /// Колбэк для возврата из секции плейлистов
  final VoidCallback? onMusicPlaylistsBack;

  /// Флаг нахождения в секции всех треков музыки
  final bool isInMusicAllTracksSection;

  /// Колбэк для возврата из секции всех треков
  final VoidCallback? onMusicAllTracksBack;

  /// Флаг нахождения в секции поиска музыки
  final bool isInMusicSearchSection;

  /// Колбэк для возврата из секции поиска музыки
  final VoidCallback? onMusicSearchBack;

  /// Флаг нахождения в секции артиста музыки
  final bool isInMusicArtistSection;

  /// Колбэк для возврата из секции артиста
  final VoidCallback? onMusicArtistBack;

  /// Виджет с именем артиста для реактивного обновления
  final Widget? artistNameWidget;

  /// Колбэк при нажатии на иконку уведомлений
  final VoidCallback? onNotificationsTap;

  /// Флаг открытого состояния уведомлений
  final bool isNotificationsOpen;

  /// Флаг скрытия бейджа уведомлений
  final bool hideNotificationsBadge;

  const AppHeader({
    super.key,
    required this.currentTabIndex,
    this.isInMusicFavoritesSection = false,
    this.onMusicFavoritesBack,
    this.isInMusicPlaylistsSection = false,
    this.onMusicPlaylistsBack,
    this.isInMusicAllTracksSection = false,
    this.onMusicAllTracksBack,
    this.isInMusicSearchSection = false,
    this.onMusicSearchBack,
    this.isInMusicArtistSection = false,
    this.onMusicArtistBack,
    this.artistNameWidget,
    this.onNotificationsTap,
    this.isNotificationsOpen = false,
    this.hideNotificationsBadge = false,
  });

  /// Возвращает название текущего таба
  String _getTabTitle() {
    switch (currentTabIndex) {
      case 0:
        return 'Профиль';
      case 1:
        return 'Музыка';
      case 2:
        return 'Лента';
      case 3:
        return 'Сообщения';
      case 4:
        return 'Меню';
      default:
        return 'K-Connect';
    }
  }

  /// Построение виджета заголовка в зависимости от состояния
  @override
  Widget build(BuildContext context) {
        
        // Специальный заголовок для секции любимых треков музыки
        if (isInMusicFavoritesSection && onMusicFavoritesBack != null) {
          return ValueListenableBuilder<String?>(
            valueListenable: StorageService.appBackgroundPathNotifier,
            builder: (context, backgroundPath, child) {
              final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
              final cardColor = hasBackground 
                  ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.surfaceContainerLow;
              
              return Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: onMusicFavoritesBack,
                              icon: Icon(
                                Icons.arrow_back,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Мои любимые',
                              style: AppTextStyles.postAuthor.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Card(
                      margin: EdgeInsets.zero,
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: BlocSelector<NotificationsBloc, NotificationsState, int>(
                          selector: (state) => state.unreadCount,
                          builder: (context, unreadCount) => BadgeIcon(
                            count: hideNotificationsBadge ? 0 : unreadCount,
                            onPressed: onNotificationsTap,
                            icon: Icon(
                              isNotificationsOpen ? Icons.close : Icons.notifications_outlined,
                              color: context.dynamicPrimaryColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }

    // Специальный заголовок для секции плейлистов музыки
    if (isInMusicPlaylistsSection && onMusicPlaylistsBack != null) {
      return ValueListenableBuilder<String?>(
        valueListenable: StorageService.appBackgroundPathNotifier,
        builder: (context, backgroundPath, child) {
          final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
          final cardColor = hasBackground 
              ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.surfaceContainerLow;
          
          return Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.transparent,
            child: Row(
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onMusicPlaylistsBack,
                          icon: Icon(
                            Icons.arrow_back,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Плейлисты',
                          style: AppTextStyles.postAuthor.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Card(
                  margin: EdgeInsets.zero,
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: BlocSelector<NotificationsBloc, NotificationsState, int>(
                      selector: (state) => state.unreadCount,
                      builder: (context, unreadCount) => BadgeIcon(
                        count: hideNotificationsBadge ? 0 : unreadCount,
                        onPressed: onNotificationsTap,
                        icon: Icon(
                          isNotificationsOpen ? Icons.close : Icons.notifications_outlined,
                          color: context.dynamicPrimaryColor,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

        // Специальный заголовок для секции всех треков музыки
        if (isInMusicAllTracksSection && onMusicAllTracksBack != null) {
          return ValueListenableBuilder<String?>(
            valueListenable: StorageService.appBackgroundPathNotifier,
            builder: (context, backgroundPath, child) {
              final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
              final cardColor = hasBackground 
                  ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.surfaceContainerLow;
              
              return Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: onMusicAllTracksBack,
                              icon: Icon(
                                Icons.arrow_back,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Все треки',
                              style: AppTextStyles.postAuthor.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Card(
                      margin: EdgeInsets.zero,
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: BlocSelector<NotificationsBloc, NotificationsState, int>(
                          selector: (state) => state.unreadCount,
                          builder: (context, unreadCount) => BadgeIcon(
                            count: hideNotificationsBadge ? 0 : unreadCount,
                            onPressed: onNotificationsTap,
                            icon: Icon(
                              isNotificationsOpen ? Icons.close : Icons.notifications_outlined,
                              color: context.dynamicPrimaryColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }

        // Специальный заголовок для секции поиска музыки
        if (isInMusicSearchSection && onMusicSearchBack != null) {
          return ValueListenableBuilder<String?>(
            valueListenable: StorageService.appBackgroundPathNotifier,
            builder: (context, backgroundPath, child) {
              final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
              final cardColor = hasBackground 
                  ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.surfaceContainerLow;
              
              return Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: onMusicSearchBack,
                              icon: Icon(
                                Icons.arrow_back,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Поиск музыки',
                              style: AppTextStyles.postAuthor.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Card(
                      margin: EdgeInsets.zero,
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: BlocSelector<NotificationsBloc, NotificationsState, int>(
                          selector: (state) => state.unreadCount,
                          builder: (context, unreadCount) => BadgeIcon(
                            count: hideNotificationsBadge ? 0 : unreadCount,
                            onPressed: onNotificationsTap,
                            icon: Icon(
                              isNotificationsOpen ? Icons.close : Icons.notifications_outlined,
                              color: context.dynamicPrimaryColor,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }

        // Специальный заголовок для секции артиста музыки
        if (isInMusicArtistSection && onMusicArtistBack != null) {
          return ValueListenableBuilder<String?>(
            valueListenable: StorageService.appBackgroundPathNotifier,
            builder: (context, backgroundPath, child) {
              final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
              final cardColor = hasBackground 
                  ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.surfaceContainerLow;
              
              return Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      color: cardColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: onMusicArtistBack,
                              icon: Icon(
                                Icons.arrow_back,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            artistNameWidget ?? const Text('Артист'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }

        // Стандартный заголовок
        return ValueListenableBuilder<String?>(
          valueListenable: StorageService.appBackgroundPathNotifier,
          builder: (context, backgroundPath, child) {
            final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
            final cardColor = hasBackground 
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                  : Theme.of(context).colorScheme.surfaceContainerLow;
            
            return Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.transparent,
              child: Row(
                children: [
                  // Логотип и название в отдельной карточке
                  Card(
                    margin: EdgeInsets.zero,
                    color: cardColor,
                    child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'lib/assets/icons/logo.svg',
                        height: 20,
                        width: 20,
                        colorFilter: ColorFilter.mode(context.dynamicPrimaryColor, BlendMode.srcIn),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isNotificationsOpen ? 'Уведомления' : _getTabTitle(),
                        style: AppTextStyles.postAuthor.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Кнопка уведомлений в отдельной карточке
              Card(
                margin: EdgeInsets.zero,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: BlocSelector<NotificationsBloc, NotificationsState, int>(
                    selector: (state) => state.unreadCount,
                    builder: (context, unreadCount) => BadgeIcon(
                      count: hideNotificationsBadge ? 0 : unreadCount,
                      onPressed: onNotificationsTap,
                      icon: Icon(
                        isNotificationsOpen ? Icons.close : Icons.notifications_outlined,
                        color: context.dynamicPrimaryColor,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          );
        },
      );
  }
}
