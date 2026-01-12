import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cupertino_back_gesture/cupertino_back_gesture.dart';
import 'injection.dart';
import 'theme/app_theme.dart';
import 'bootstrap/splash_screen.dart';
import 'routes/app_router.dart';
import 'core/theme/presentation/blocs/theme_bloc.dart';
import 'core/theme/presentation/blocs/theme_state.dart';
import 'features/auth/presentation/blocs/auth_bloc.dart';
import 'features/auth/presentation/blocs/account_bloc.dart';
import 'features/music/presentation/blocs/queue_bloc.dart';
import 'features/music/presentation/blocs/music_bloc.dart';

import 'features/profile/presentation/blocs/profile_bloc.dart';
import 'features/messages/presentation/blocs/messages_bloc.dart';
import 'features/feed/presentation/blocs/feed_bloc.dart';
import 'features/notifications/presentation/bloc/notifications_bloc.dart';
import 'features/notifications/domain/notifications_repository.dart';
import 'services/media_player_service.dart';

/// Главный виджет приложения K-Connect
///
/// Настраивает все BLoC провайдеры, тему приложения, локализацию
/// и навигацию. Служит корневым виджетом всего приложения.
class KConnectApp extends StatefulWidget {
  const KConnectApp({super.key});

  @override
  State<KConnectApp> createState() => _KConnectAppState();
}

class _KConnectAppState extends State<KConnectApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(create: (_) => locator<AuthBloc>(), lazy: false),
          BlocProvider<AccountBloc>(create: (_) => locator<AccountBloc>(), lazy: false),
          BlocProvider<QueueBloc>(create: (_) => locator<QueueBloc>(), lazy: false),
          BlocProvider<MusicBloc>(create: (_) => locator<MusicBloc>(), lazy: true),
          BlocProvider<FeedBloc>(create: (_) => locator<FeedBloc>()),
          BlocProvider<ProfileBloc>(
            create: (context) {
              return locator<ProfileBloc>();
            },
            lazy: true,
          ),
          BlocProvider<MessagesBloc>(create: (_) => locator<MessagesBloc>(), lazy: false),
          BlocProvider<NotificationsBloc>(
            create: (_) => NotificationsBloc(locator<NotificationsRepository>()),
            lazy: false,
          ),
        ],
        child: Builder(
          builder: (context) {
            // Инициализируем MediaPlayerService после создания BlocProvider
            // чтобы использовать правильный экземпляр QueueBloc
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                final queueBloc = context.read<QueueBloc>();
                MediaPlayerService.initialize(queueBloc);
                if (kDebugMode) {
                  debugPrint('App: MediaPlayerService initialized successfully');
                }
              } catch (e, stackTrace) {
                if (kDebugMode) {
                  debugPrint('App: Error initializing MediaPlayerService: $e');
                  debugPrint('App: Stack trace: $stackTrace');
                }
              }
            });

            return BlocProvider.value(
              value: locator<ThemeBloc>(),
              child: BlocBuilder<ThemeBloc, ThemeState>(
                builder: (context, themeState) {
              final colorScheme = themeState is ThemeLoaded
                  ? themeState.colorScheme
                  : ColorScheme.fromSeed(
                      seedColor: const Color(0xFFD0BCFF),
                      brightness: Brightness.dark,
                    );

              return DefaultTextStyle(
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFFEAEAEA),
                ),
                child: BackGestureWidthTheme(
                  backGestureWidth: BackGestureWidth.fraction(1),
                  child: MaterialApp(
                    title: 'K-Connect',
                    debugShowCheckedModeBanner: false,
                    navigatorKey: AppRouter.navigatorKey,
                    theme: AppTheme.materialDarkTheme(colorScheme).copyWith(
                      pageTransitionsTheme: const PageTransitionsTheme(
                        builders: {
                          TargetPlatform.android: CupertinoPageTransitionsBuilderCustomBackGestureWidth(),
                          TargetPlatform.iOS: CupertinoPageTransitionsBuilderCustomBackGestureWidth(),
                        },
                      ),
                    ),
                    home: const SplashScreen(),
                    onGenerateRoute: AppRouter.generateRoute,
                    localizationsDelegates: const [
                      GlobalCupertinoLocalizations.delegate,
                      GlobalMaterialLocalizations.delegate,
                      GlobalWidgetsLocalizations.delegate,
                    ],
                    supportedLocales: const [
                      Locale('en', 'US'),
                      Locale('ru', 'RU'),
                    ],
                  ),
                ),
              );
                },
              ),
            );
          },
        ),
    );
  }
}
