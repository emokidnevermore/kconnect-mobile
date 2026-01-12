/// Экран управления черным списком
///
/// Позволяет пользователю просматривать и управлять заблокированными пользователями.
library;

import 'package:flutter/material.dart';
import 'package:kconnect_mobile/features/feed/domain/usecases/block_user_usecase.dart';
import '../../theme/app_text_styles.dart';
import '../../core/utils/theme_extensions.dart';
import '../../core/widgets/app_background.dart';
import '../../features/profile/components/swipe_pop_container.dart';
import '../../services/storage_service.dart';
import '../../features/feed/domain/models/block_status.dart';
import '../../core/usecase/usecase.dart';
import '../../injection.dart';

/// Экран черного списка
///
/// Предоставляет интерфейс для управления заблокированными пользователями:
/// просмотр списка, разблокировка пользователей.
class BlacklistScreen extends StatefulWidget {
  const BlacklistScreen({super.key});

  @override
  State<BlacklistScreen> createState() => _BlacklistScreenState();
}

class _BlacklistScreenState extends State<BlacklistScreen> {
  List<BlockedUser> _blockedUsers = [];
  BlacklistStats? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
    _loadBlacklistStats();
  }

  Future<void> _loadBlacklistStats() async {
    try {
      final useCase = locator<GetBlacklistStatsUseCase>();
      final result = await useCase.call(NoParams());

      result.fold(
        (failure) {
          debugPrint('❌ Failed to load blacklist stats: $failure');
          // Don't show error for stats, just silently fail
        },
        (response) {
          debugPrint('✅ Loaded blacklist stats: ${response.stats.totalBlocked} blocked, ${response.stats.totalBlockedBy} blocked by');
          setState(() {
            _stats = response.stats;
          });
        },
      );
    } catch (e) {
      debugPrint('💥 Error loading blocked users: $e');
      // Handle error silently
    }
  }

  Future<void> _loadBlockedUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final useCase = locator<GetBlockedUsersUseCase>();
      final result = await useCase.call(NoParams());

      result.fold(
        (failure) {
          debugPrint('❌ Failed to load blocked users: $failure');
          // Handle error silently
        },
        (response) {
          debugPrint('✅ Loaded ${response.blockedUsers.length} blocked users');
          setState(() {
            _blockedUsers = response.blockedUsers;
          });
        },
      );
    } catch (e) {
      debugPrint('💥 Error loading blocked users: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _unblockUser(BlockedUser user) async {
    try {
      final useCase = locator<UnblockUserUseCase>();
      final result = await useCase.call(user.id);

      result.fold(
        (failure) {
          debugPrint('❌ Failed to unblock user ${user.id}: $failure');
          // Handle error silently
        },
        (response) {
          debugPrint('✅ Successfully unblocked user ${user.id}');
          // Remove user from list
          setState(() {
            _blockedUsers.removeWhere((u) => u.id == user.id);
          });
        },
      );
    } catch (e) {
      debugPrint('💥 Error unblocking user ${user.id}: $e');
      // Handle error silently
    }
  }



  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AppBackground(fallbackColor: Theme.of(context).colorScheme.surface),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: SwipePopContainer(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadBlockedUsers,
                      child: CustomScrollView(
                        slivers: [
                          // Отступ сверху для хедера
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 72),
                          ),
                          // Статистика черного списка
                          if (_stats != null) ...[
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                                child: _buildStatsCard(
                                  context,
                                  'Заблокировано пользователей',
                                  _stats!.totalBlocked.toString(),
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 24),
                                child: _buildStatsCard(
                                  context,
                                  'Заблокировали меня',
                                  _stats!.totalBlockedBy.toString(),
                                ),
                              ),
                            ),
                          ],
                          // Заголовок списка
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Заблокированные пользователи',
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 16),
                          ),
                          // Список пользователей
                          if (_blockedUsers.isEmpty)
                            SliverToBoxAdapter(
                              child: _buildEmptyState(),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final user = _blockedUsers[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _buildUserCard(user),
                                    );
                                  },
                                  childCount: _blockedUsers.length,
                                ),
                              ),
                            ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 24),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        // Кастомный хедер с карточками (поверх всего)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: ValueListenableBuilder<String?>(
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
                      // Карточка слева: кнопка назад и название
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
                                onPressed: () => Navigator.of(context).pop(),
                                icon: Icon(
                                  Icons.arrow_back,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Черный список',
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
                      // Карточка справа: пустая для симметрии
                      const SizedBox(width: 56),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Черный список пуст',
              style: AppTextStyles.h3.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Здесь будут отображаться пользователи, которых вы заблокировали',
              style: AppTextStyles.body.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(BlockedUser user) {
    return ValueListenableBuilder<String?>(
      valueListenable: StorageService.appBackgroundPathNotifier,
      builder: (context, backgroundPath, child) {
        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
        final cardColor = hasBackground
            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
            : Theme.of(context).colorScheme.surfaceContainerLow;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Аватар пользователя
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: NetworkImage(
                        'https://s3.k-connect.ru/static/uploads/avatar/${user.id}/${user.photo}',
                      ),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        // Fallback to default avatar
                      },
                    ),
                  ),
                  child: user.photo.isEmpty
                      ? Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                // Информация о пользователе
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            user.name,
                            style: AppTextStyles.button.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (user.verification != null && user.verification! > 0)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.verified,
                                size: 16,
                                color: context.dynamicPrimaryColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Кнопка разблокировки
                TextButton(
                  onPressed: () => _showUnblockDialog(user),
                  style: TextButton.styleFrom(
                    foregroundColor: context.dynamicPrimaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Разблокировать'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUnblockDialog(BlockedUser user) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Разблокировать пользователя?',
          style: AppTextStyles.h3.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        content: Text(
          'Вы сможете снова видеть посты ${user.name} и взаимодействовать с ними.',
          style: AppTextStyles.body.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Отмена',
              style: AppTextStyles.button.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _unblockUser(user);
            },
            style: TextButton.styleFrom(
              foregroundColor: context.dynamicPrimaryColor,
            ),
            child: const Text('Разблокировать'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard(BuildContext context, String title, String value) {
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: AppTextStyles.h3.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodySecondary.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
