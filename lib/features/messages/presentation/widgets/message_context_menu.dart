import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/features/messages/domain/models/message.dart';

/// Контекстное меню сообщения с опциями ответа, редактирования, удаления,
/// пересылки, копирования и просмотра медиа
class MessageContextMenu {
  /// Показать контекстное меню для сообщения
  static void show(
    BuildContext context, {
    required Message message,
    required bool isCurrentUser,
    required Function(Message) onReply,
    required Function(Message)? onEdit,
    required Function(Message)? onDelete,
    required Function(Message)? onForward,
    required Function(Message)? onOpenMedia,
  }) {
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
            color: Theme.of(context).colorScheme.surfaceContainer,
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
              // Ответить
              _buildMenuItem(
                context: context,
                icon: Icons.reply,
                title: 'Ответить',
                onTap: () => onReply(message),
              ),
              // Редактировать (только свои сообщения и только текстовые)
              if (isCurrentUser && message.messageType == MessageType.text && onEdit != null) ...[
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.edit,
                  title: 'Редактировать',
                  onTap: () => onEdit(message),
                ),
              ],
              // Удалить (только свои сообщения)
              if (isCurrentUser && onDelete != null) ...[
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.delete,
                  title: 'Удалить',
                  onTap: () => onDelete(message),
                  isDestructive: true,
                ),
              ],
              // Переслать
              if (onForward != null) ...[
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.forward,
                  title: 'Переслать',
                  onTap: () => onForward(message),
                ),
              ],
              // Копировать текст (только для текстовых сообщений)
              if (message.messageType == MessageType.text) ...[
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                ),
                _buildMenuItem(
                  context: context,
                  icon: Icons.copy,
                  title: 'Копировать текст',
                  onTap: () => _copyText(context, message),
                ),
              ],
              // Открыть медиа на весь экран (для фото/видео)
              if ((message.messageType == MessageType.photo || 
                   message.messageType == MessageType.video) && 
                  onOpenMedia != null) ...[
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.1),
                ),
                _buildMenuItem(
                  context: context,
                  icon: message.messageType == MessageType.photo ? Icons.image : Icons.videocam,
                  title: message.messageType == MessageType.photo ? 'Открыть фото' : 'Открыть видео',
                  onTap: () => onOpenMedia(message),
                ),
              ],
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

  /// Копирует текст сообщения в буфер обмена
  static Future<void> _copyText(BuildContext context, Message message) async {
    await Clipboard.setData(ClipboardData(text: message.content));

    // Показать уведомление об успешном копировании
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Текст скопирован',
            style: AppTextStyles.body.copyWith(color: Theme.of(context).colorScheme.onSurface),
          ),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
