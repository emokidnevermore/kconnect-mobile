import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import '../routes/route_names.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import '../theme/app_text_styles.dart';
import '../features/auth/presentation/blocs/auth_bloc.dart';
import '../features/auth/presentation/blocs/auth_event.dart';
import '../features/auth/presentation/blocs/auth_state.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Экран загрузки приложения
///
/// Отображает логотип и индикатор загрузки во время проверки сессии пользователя.
/// Перенаправляет на главный экран или экран входа в зависимости от наличия активной сессии.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _status = 'K-Connect загружается...';

  @override
  void initState() {
    super.initState();
    setState(() => _status = 'initState called');
    _checkSession();
  }

  /// Проверяет наличие активной сессии и перенаправляет пользователя
  Future<void> _checkSession() async {
    setState(() => _status = '_checkSession started');
    
    // Проверяем наличие сессии в хранилище
    final hasSession = await StorageService.hasActiveSession().timeout(
      const Duration(seconds: 3),
      onTimeout: () => false,
    );
    setState(() => _status = 'after storage: $hasSession');

    if (!mounted) return;

    // Вызываем CheckAuthEvent в AuthBloc для проверки валидности сессии
    if (hasSession) {
      setState(() => _status = 'Checking auth with AuthBloc...');
      context.read<AuthBloc>().add(CheckAuthEvent());
      
      // Слушаем изменения состояния AuthBloc
      context.read<AuthBloc>().stream.listen((authState) {
        if (!mounted) return;
        
        if (authState is AuthAuthenticated) {
          setState(() => _status = 'Authenticated, navigating...');
          Navigator.pushReplacementNamed(context, RouteNames.mainTabs);
        } else if (authState is AuthUnauthenticated || authState is AuthError) {
          setState(() => _status = 'Not authenticated, going to login...');
          Navigator.pushReplacementNamed(context, RouteNames.login);
        }
      });
      
      // Таймаут на случай, если AuthBloc не ответит
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          final currentState = context.read<AuthBloc>().state;
          if (currentState is AuthInitial || currentState is AuthLoading) {
            // Если все еще загружается, переходим на mainTabs (там будет проверка)
            Navigator.pushReplacementNamed(context, RouteNames.mainTabs);
          }
        }
      });
    } else {
      Navigator.pushReplacementNamed(context, RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'lib/assets/icons/logo.svg',
              width: 96,
              height: 96,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(strokeWidth: 3),
            const SizedBox(height: 24),
            Text(
              _status,
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.dynamicPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
