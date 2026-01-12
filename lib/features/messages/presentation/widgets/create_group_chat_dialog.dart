import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_event.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';

/// Диалог создания группового чата
///
/// Позволяет создать групповой чат, выбрав название и участников
class CreateGroupChatDialog extends StatefulWidget {
  final List<int>? initialUserIds; // Предвыбранные пользователи (опционально)

  const CreateGroupChatDialog({
    super.key,
    this.initialUserIds,
  });

  @override
  State<CreateGroupChatDialog> createState() => _CreateGroupChatDialogState();
}

class _CreateGroupChatDialogState extends State<CreateGroupChatDialog> {
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _userSearchController = TextEditingController();
  final Set<int> _selectedUserIds = {};
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUserIds != null) {
      _selectedUserIds.addAll(widget.initialUserIds!);
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _userSearchController.dispose();
    super.dispose();
  }

  void _createGroupChat() {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название группы'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите хотя бы одного участника'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    context.read<MessagesBloc>().add(
      CreateGroupChatEvent(
        title: _groupNameController.text.trim(),
        userIds: _selectedUserIds.toList(),
      ),
    );

    // Close dialog after creation
    // The BLoC will update the chat list via WebSocket
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Создать групповой чат',
              style: AppTextStyles.h2.copyWith(
                color: context.dynamicPrimaryColor,
              ),
            ),
            const SizedBox(height: 24),
            // Group name input
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                labelText: 'Название группы',
                labelStyle: TextStyle(
                  color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: context.dynamicPrimaryColor,
                  ),
                ),
              ),
              style: AppTextStyles.body.copyWith(
                color: context.dynamicPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            // User search input
            TextField(
              controller: _userSearchController,
              decoration: InputDecoration(
                labelText: 'Поиск пользователей',
                labelStyle: TextStyle(
                  color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: context.dynamicPrimaryColor,
                  ),
                ),
              ),
              style: AppTextStyles.body.copyWith(
                color: context.dynamicPrimaryColor,
              ),
            ),
            const SizedBox(height: 16),
            // Selected users chips
            if (_selectedUserIds.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedUserIds.map((userId) {
                  return Chip(
                    label: Text(
                      'Пользователь $userId',
                      style: TextStyle(
                        color: context.dynamicPrimaryColor,
                        fontSize: 12,
                      ),
                    ),
                    onDeleted: () {
                      setState(() {
                        _selectedUserIds.remove(userId);
                      });
                    },
                    backgroundColor: context.dynamicPrimaryColor.withValues(alpha: 0.1),
                    deleteIcon: Icon(
                      Icons.close,
                      size: 16,
                      color: context.dynamicPrimaryColor,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            // Info text
            Text(
              'TODO: Реализовать поиск и выбор пользователей через API',
              style: AppTextStyles.bodySecondary.copyWith(
                color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 24),
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Отмена',
                    style: TextStyle(
                      color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isCreating ? null : _createGroupChat,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.dynamicPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: _isCreating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Создать'),
                ),
              ],
            ),
          ],
        ),
      ),
        ),
    );
  }
}
