/// Экран меню настроек приложения
///
/// Предоставляет доступ к различным настройкам приложения:
/// очистка кеша, персонализация, информация о приложении.
/// Использует Sliver для создания прокручиваемого интерфейса.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../theme/app_text_styles.dart';
import '../../../core/utils/theme_extensions.dart';
import '../../../routes/route_names.dart';
import '../../../features/auth/presentation/blocs/auth_bloc.dart';
import '../../../features/auth/presentation/blocs/auth_state.dart';
import '../../../services/storage_service.dart';

/// Экран меню с настройками приложения
///
/// Содержит список опций для управления приложением:
/// - Очистка кеша изображений
/// - Персонализация интерфейса
/// - Информация о приложении
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => current is AuthUnauthenticated,
      listener: (context, state) => Navigator.pushReplacementNamed(context, RouteNames.login),
      child: SafeArea(
        child: Container(
          color: Colors.transparent,
          child: CustomScrollView(
            slivers: [
              // Отступ сверху под хедер
              const SliverToBoxAdapter(
                child: SizedBox(height: 38),
              ),
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Аккаунт',
                    style: AppTextStyles.h2,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildMenuCard(
                        context,
                        'Черный список',
                        'Управление заблокированными пользователями',
                        Icons.block,
                        context.dynamicPrimaryColor,
                        () => _navigateToBlacklist(context),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Настройки',
                    style: AppTextStyles.h2,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _buildMenuCard(
                        context,
                        'Управление кэшем',
                        'Просмотр и управление кэшем приложения по категориям',
                        Icons.storage,
                        context.dynamicPrimaryColor,
                        () => _navigateToCacheManagement(context),
                      ),
                      const SizedBox(height: 12),
                      _buildMenuCard(
                        context,
                        'Персонализация',
                        'Настройки персонализации интерфейса приложения',
                        Icons.color_lens,
                        context.dynamicPrimaryColor,
                        () => _navigateToPersonalization(context),
                      ),
                      const SizedBox(height: 12),
                      _buildMenuCard(
                        context,
                        'О приложении',
                        'Версия приложения и информация о разработчике',
                        Icons.info_outline,
                        context.dynamicPrimaryColor,
                        () => _showAboutDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
              // Bottom padding for small screens to account for tab bar
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height < 700 ? 40 : 0,
                ),
              ),
              // Fill remaining space to ensure full height coverage
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color iconColor, VoidCallback onTap) {
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, backgroundPath, child) {
        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
        final cardColor = hasBackground 
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
            : Theme.of(context).colorScheme.surfaceContainerLow;
        
        return Card(
          margin: EdgeInsets.zero,
          color: cardColor,
          child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
        ),
        title: Text(
          title,
          style: AppTextStyles.button.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.bodySecondary.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
          );
        },
      );
  }

  void _navigateToCacheManagement(BuildContext context) {
    Navigator.of(context).pushNamed(RouteNames.cacheManagement);
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('О приложении'),
        content: const Text(
          'KConnect Mobile\n'
          'Версия: 1.1.0\n\n'
          'У меня огромные яйца',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }



  void _navigateToPersonalization(BuildContext context) {
    Navigator.of(context).pushNamed(RouteNames.personalization);
  }

  void _navigateToBlacklist(BuildContext context) {
    Navigator.of(context).pushNamed(RouteNames.blacklist);
  }
}
