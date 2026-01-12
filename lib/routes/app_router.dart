/// Маршрутизатор приложения для навигации между экранами
///
/// Определяет все маршруты приложения и обрабатывает их генерацию.
/// Поддерживает именованные маршруты и передачу аргументов между экранами.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/bootstrap/splash_screen.dart';
import 'package:kconnect_mobile/features/auth/login_screen.dart';
import 'package:kconnect_mobile/features/auth/register_screen.dart';
import 'package:kconnect_mobile/features/auth/add_account_screen.dart';
import 'package:kconnect_mobile/features/core/main_tabs.dart';
import 'package:kconnect_mobile/features/profile/other_profile_screen.dart';
import 'package:kconnect_mobile/features/personalization/personalization_screen.dart';
import 'package:kconnect_mobile/core/widgets/media_viewer.dart';
import 'package:kconnect_mobile/core/media_item.dart';
import 'package:kconnect_mobile/features/post_creation/presentation/screens/post_creation_screen.dart';
import 'package:kconnect_mobile/features/post_creation/presentation/blocs/post_creation_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/screens/create_chat_screen.dart';
import 'package:kconnect_mobile/features/cache_management/cache_management_screen.dart';
import 'package:kconnect_mobile/features/menu/blacklist_screen.dart';
import 'package:kconnect_mobile/injection.dart';
import 'route_names.dart';

/// Основной маршрутизатор приложения
class AppRouter {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteNames.splash:
        return CupertinoPageRoute(builder: (_) => const SplashScreen());
      case RouteNames.login:
        return CupertinoPageRoute(builder: (_) => const LoginScreen());
      case RouteNames.register:
        return CupertinoPageRoute(builder: (_) => const RegisterScreen());
      case RouteNames.addAccount:
        debugPrint('AppRouter: Navigating to AddAccountScreen');
        return CupertinoPageRoute(builder: (_) => const AddAccountScreen());
      case RouteNames.mainTabs:
        // Slide transition для главных табов
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const MainTabs(),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide transition для горизонтальной навигации
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        );
      case RouteNames.profile:
        final username = settings.arguments as String;
        // Используем PageRouteBuilder с плавной анимацией для профиля
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return OtherProfileScreen(username: username);
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Плавный fade + scale transition для профиля
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.95,
                  end: 1.0,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOut,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
      case RouteNames.personalization:
        // Fade transition для модальных окон
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const PersonalizationScreen(),
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
      case RouteNames.mediaViewer:
        final args = settings.arguments as Map<String, dynamic>;
        final items = args['items'] as List<MediaItem>;
        final initialIndex = args['initialIndex'] as int? ?? 0;
        final heroTagPrefix = args['heroTagPrefix'] as String?;
        final postId = args['postId'] as int?;
        final feedIndex = args['feedIndex'] as int?;
        // Используем PageRouteBuilder с fade transition для Hero анимаций
        // чтобы стандартная навигационная анимация не мешала Hero
        return PageRouteBuilder(
          opaque: false, // Позволяет Hero анимации работать правильно
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) {
            return MediaViewer(
              items: items,
              initialIndex: initialIndex,
              heroTagPrefix: heroTagPrefix,
              postId: postId,
              feedIndex: feedIndex,
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Простой fade transition, чтобы не конфликтовать с Hero
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
      case RouteNames.createPost:
        // Slide + scale transition для создания поста
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return BlocProvider.value(
              value: locator<PostCreationBloc>(),
              child: const PostCreationScreen(),
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Slide up + fade для модального экрана создания поста
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                ),
              ),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        );
      case RouteNames.createChat:
        return CupertinoPageRoute(
          builder: (_) => const CreateChatScreen(),
        );
      case RouteNames.cacheManagement:
        // Fade transition для экрана управления кэшем
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const CacheManagementScreen(),
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
      case RouteNames.blacklist:
        // Fade transition для экрана черного списка
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const BlacklistScreen(),
          transitionDuration: const Duration(milliseconds: 250),
          reverseTransitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
        );
      default:
        return CupertinoPageRoute(builder: (_) => const SplashScreen());
    }
  }
}
