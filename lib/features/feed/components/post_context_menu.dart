import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_text_styles.dart';
import '../../../services/storage_service.dart';
import '../../../features/feed/domain/models/post.dart';
import '../../../features/feed/domain/usecases/block_user_usecase.dart';
import '../../../injection.dart';
import '../../../routes/app_router.dart';
import 'complaint_modal.dart';

/// Контекстное меню поста с опциями просмотров, копирования ссылки,
/// блокировки и жалобы
class PostContextMenu {
  /// Показать контекстное меню для поста
  static void show(BuildContext context, Post post) {
    // Определяем цвет фона меню в зависимости от наличия фонового изображения
    final hasBackground = StorageService.appBackgroundPathNotifier.value?.isNotEmpty ?? false;
    final menuBackgroundColor = hasBackground
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.9)
        : Theme.of(context).colorScheme.surfaceContainerLow;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: menuBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar для Material 3
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Информация о просмотрах
              ListTile(
                leading: Icon(
                  Icons.visibility,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  '${post.viewsCount ?? 0} просмотров',
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              // Разделитель
              Divider(
                height: 1,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
              ),

              // Опции действий
              _buildMenuItem(
                context: context,
                icon: Icons.link,
                title: 'Копировать ссылку',
                onTap: () => _copyLink(context, post),
              ),

              FutureBuilder<bool>(
                future: _checkBlockStatus(post.userId),
                builder: (context, snapshot) {
                  final isBlocked = snapshot.data ?? false;
                  return _buildMenuItem(
                    context: context,
                    icon: isBlocked ? Icons.check_circle : Icons.block,
                    title: isBlocked ? 'Разблокировать' : 'Заблокировать',
                    onTap: () => _blockUser(context, post),
                    isDestructive: !isBlocked,
                  );
                },
              ),

              _buildMenuItem(
                context: context,
                icon: Icons.warning,
                title: 'Пожаловаться',
                onTap: () => _reportPost(context, post),
                isDestructive: true,
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Создает элемент меню
  static Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final destructiveColor = Theme.of(context).colorScheme.error;
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: isDestructive ? destructiveColor : Theme.of(context).colorScheme.onSurface,
      ),
      title: Text(
        title,
        style: AppTextStyles.body.copyWith(
          color: isDestructive ? destructiveColor : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }

  /// Копирует ссылку на пост в буфер обмена
  static Future<void> _copyLink(BuildContext context, Post post) async {
    final link = 'https://k-connect.ru/post/${post.id}';
    await Clipboard.setData(ClipboardData(text: link));

    // Показать уведомление об успешном копировании
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ссылка скопирована',
            style: AppTextStyles.body.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Функция блокировки пользователя
  static void _blockUser(BuildContext context, Post post) async {


    try {
      // Получаем статус блокировки через API
      final checkStatusUseCase = locator<CheckBlockStatusUseCase>();
      final statusResult = await checkStatusUseCase.call([post.userId]);

      final isBlocked = statusResult.fold(
        (failure) {
          return false;
        },
        (statusResponse) {
          final blocked = statusResponse.blockedStatus[post.userId] ?? false;
          return blocked;
        },
      );

      // Показываем уведомление перед выполнением операции
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBlocked ? 'Разблокировка пользователя...' : 'Блокировка пользователя...',
              style: AppTextStyles.body.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            duration: const Duration(seconds: 1),
          ),
        );
      }

      final shouldBlock = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(
            isBlocked ? 'Разблокировать пользователя?' : 'Заблокировать пользователя?',
            style: AppTextStyles.h3.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          content: Text(
            isBlocked
                ? 'Вы сможете снова видеть посты этого пользователя и взаимодействовать с ними.'
                : 'Вы больше не будете видеть посты этого пользователя. Это действие можно отменить.',
            style: AppTextStyles.body.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                debugPrint('❌ User cancelled block/unblock action');
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(
                'Отмена',
                style: AppTextStyles.button.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                debugPrint('✅ User confirmed block/unblock action');
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(
                isBlocked ? 'Разблокировать' : 'Заблокировать',
                style: AppTextStyles.button.copyWith(
                  color: isBlocked
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      );


      if (shouldBlock == true) {
        // Выполняем блокировку/разблокировку через API
        if (isBlocked) {
          // Разблокировка
          final unblockUseCase = locator<UnblockUserUseCase>();
          final unblockResult = await unblockUseCase.call(post.userId);

          unblockResult.fold(
            (failure) {
              throw Exception('Не удалось разблокировать пользователя');
            },
            (response) {
              _showSuccessMessage(response.message);
            },
          );
        } else {
          // Блокировка
          final blockUseCase = locator<BlockUserUseCase>();
          final blockResult = await blockUseCase.call(post.userId);

          blockResult.fold(
            (failure) {
              throw Exception('Не удалось заблокировать пользователя');
            },
            (response) {
              _showSuccessMessage(response.message);
            },
          );
        }
      } else {
        debugPrint('⏹️ Operation cancelled by user');
      }
    } catch (e) {
      debugPrint('💥 Error in block/unblock process: $e');
      _showErrorMessage('Ошибка: $e');
    }
  }

  /// Показывает сообщение об успехе
  static void _showSuccessMessage(String message) {
    // Используем глобальный контекст для показа уведомления
    final context = AppRouter.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.body.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Показывает сообщение об ошибке
  static void _showErrorMessage(String message) {
    // Используем глобальный контекст для показа уведомления
    final context = AppRouter.navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: AppTextStyles.body.copyWith(color: Theme.of(context).colorScheme.onError),
          ),
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Проверяет статус блокировки пользователя
  static Future<bool> _checkBlockStatus(int? userId) async {
    if (userId == null) return false;

    try {
      final checkStatusUseCase = locator<CheckBlockStatusUseCase>();
      final statusResult = await checkStatusUseCase.call([userId]);

      return statusResult.fold(
        (failure) => false, // В случае ошибки считаем, что не заблокирован
        (statusResponse) => statusResponse.blockedStatus[userId] ?? false,
      );
    } catch (e) {
      return false; // В случае ошибки считаем, что не заблокирован
    }
  }

  /// Функция жалобы на пост
  static void _reportPost(BuildContext context, Post post) {
    ComplaintModal.show(
      context,
      postId: post.id,
      onComplaintSubmitted: (response) {
        // Обработка успешной отправки жалобы
        debugPrint('Жалоба отправлена: ${response.message}');
      },
    );
  }
}
