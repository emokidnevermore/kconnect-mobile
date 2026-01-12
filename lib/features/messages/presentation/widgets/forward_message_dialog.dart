import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/features/messages/domain/models/chat.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_event.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_state.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';

/// Диалог выбора чата для пересылки сообщения
class ForwardMessageDialog extends StatelessWidget {
  final int messageId;
  final int fromChatId;

  const ForwardMessageDialog({
    super.key,
    required this.messageId,
    required this.fromChatId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<MessagesBloc, MessagesState, List<Chat>>(
      selector: (state) => state.chats.where((chat) => chat.id != fromChatId).toList(),
      builder: (context, availableChats) {

        if (availableChats.isEmpty) {
          return AlertDialog(
            title: const Text('Нет доступных чатов'),
            content: const Text('Нет других чатов для пересылки сообщения.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ОК'),
              ),
            ],
          );
        }

        return AlertDialog(
          title: Text(
            'Выберите чат',
            style: AppTextStyles.h3.copyWith(
              color: context.dynamicPrimaryColor,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: availableChats.length,
              itemBuilder: (context, index) {
                final chat = availableChats[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                    child: Text(
                      chat.title.isNotEmpty ? chat.title[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: context.dynamicPrimaryColor,
                      ),
                    ),
                  ),
                  title: Text(
                    chat.title,
                    style: AppTextStyles.body.copyWith(
                      color: context.dynamicPrimaryColor,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.read<MessagesBloc>().add(ForwardMessageEvent(
                      fromChatId: fromChatId,
                      messageId: messageId,
                      toChatId: chat.id,
                    ));
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Отмена',
                style: TextStyle(
                  color: context.dynamicPrimaryColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
