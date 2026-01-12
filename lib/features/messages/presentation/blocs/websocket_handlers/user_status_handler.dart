import 'package:flutter/foundation.dart';
import '../../../../../services/messenger_websocket_service.dart';
import '../../../../auth/presentation/blocs/auth_bloc.dart';
import 'package:kconnect_mobile/features/messages/domain/models/chat_member.dart';
import '../messages_state.dart';
import 'websocket_event_handler.dart';

/// Обработчик событий обновления статусов пользователей
///
/// Обрабатывает событие `user_status` для обновления статусов онлайн/офлайн
/// участников чатов в real-time
class UserStatusHandler extends WebSocketEventHandler {
  @override
  MessagesState handle(
    MessagesState state,
    Map<String, dynamic> data,
    AuthBloc authBloc,
    MessengerWebSocketService wsService,
  ) {
    try {
      debugPrint('UserStatusHandler: Processing user_status event');

      final userId = data['user_id'] as int?;
      final isOnline = data['is_online'] as bool? ?? false;
      final lastActiveStr = data['last_active'] as String?;

      if (userId == null) {
        debugPrint('UserStatusHandler: user_id is null, skipping');
        return state;
      }

      debugPrint('UserStatusHandler: Updating status for user $userId: isOnline=$isOnline');

      // Parse last_active if provided
      DateTime? lastActive;
      if (lastActiveStr != null) {
        try {
          lastActive = DateTime.parse(lastActiveStr).toLocal();
        } catch (e) {
          debugPrint('UserStatusHandler: Failed to parse last_active: $e');
        }
      }

      // Update user statuses in state
      // This will be used by ChatHeader and ChatTile to show online status
      final updatedChats = state.chats.map((chat) {
        // Check if this user is a member of this chat
        final memberIndex = chat.members.indexWhere((m) => m.userId == userId);
        if (memberIndex == -1) {
          // User is not a member of this chat, skip
          return chat;
        }

        final member = chat.members[memberIndex];

        // Create updated member with new status
        final updatedMember = ChatMember(
          userId: member.userId,
          role: member.role,
          name: member.name,
          username: member.username,
          avatar: member.avatar,
          isOnline: isOnline,
          joinedAt: member.joinedAt,
          lastActive: lastActive ?? member.lastActive,
          accountType: member.accountType,
        );

        // Update members list
        final updatedMembers = List<ChatMember>.from(chat.members);
        updatedMembers[memberIndex] = updatedMember;

        return chat.copyWith(members: updatedMembers);
      }).toList();

      // Update filtered chats too
      final updatedFilteredChats = state.filteredChats.map((chat) {
        final memberIndex = chat.members.indexWhere((m) => m.userId == userId);
        if (memberIndex == -1) {
          return chat;
        }

        final member = chat.members[memberIndex];

        final updatedMember = ChatMember(
          userId: member.userId,
          role: member.role,
          name: member.name,
          username: member.username,
          avatar: member.avatar,
          isOnline: isOnline,
          joinedAt: member.joinedAt,
          lastActive: lastActive ?? member.lastActive,
          accountType: member.accountType,
        );

        final updatedMembers = List<ChatMember>.from(chat.members);
        updatedMembers[memberIndex] = updatedMember;

        return chat.copyWith(members: updatedMembers);
      }).toList();

      debugPrint('UserStatusHandler: Status updated successfully for user $userId');
      
      return state.copyWith(
        chats: updatedChats,
        filteredChats: updatedFilteredChats,
      );
    } catch (e, stackTrace) {
      debugPrint('UserStatusHandler: Error processing user_status: $e');
      debugPrint('UserStatusHandler: Stack trace: $stackTrace');
      return state;
    }
  }
}
