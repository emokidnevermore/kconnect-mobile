/// Виджет хедера чата
///
/// Отображает кнопку назад, аватар, никнейм, статус онлайна и кнопку меню
library;

import 'package:flutter/material.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/core/widgets/authorized_cached_network_image.dart';
import 'package:kconnect_mobile/features/messages/domain/models/chat.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import '../../chat_screen.dart' show OnlineStatusInfo, OnlineStatusType;

/// Хедер чата с информацией о собеседнике
class ChatHeader extends StatelessWidget {
  final Chat chat;
  final OnlineStatusInfo onlineStatus;
  final bool isTyping;
  final VoidCallback? onMenuPressed;
  final VoidCallback? onSearchTap;

  const ChatHeader({
    super.key,
    required this.chat,
    required this.onlineStatus,
    this.isTyping = false,
    this.onMenuPressed,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
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
              // Left card: back button
              Card(
                margin: EdgeInsets.zero,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: context.dynamicPrimaryColor,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Center card: avatar, nickname, status
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  color: cardColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: context.dynamicPrimaryColor.withValues(alpha: 0.2),
                          ),
                          child: chat.avatar != null && chat.avatar!.isNotEmpty
                              ? ClipOval(
                                  child: AuthorizedCachedNetworkImage(
                                    imageUrl: chat.avatar!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Icon(
                                      Icons.person,
                                      color: context.dynamicPrimaryColor,
                                      size: 18,
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.person,
                                      color: context.dynamicPrimaryColor,
                                      size: 18,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  color: context.dynamicPrimaryColor,
                                  size: 18,
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            chat.title,
                            style: AppTextStyles.h3.copyWith(
                              color: context.dynamicPrimaryColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Online status icon or typing indicator
                        isTyping
                            ? _buildTypingIndicator(context)
                            : _buildOnlineStatusIcon(context),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Right card: menu button
              Card(
                margin: EdgeInsets.zero,
                color: cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: onMenuPressed ?? () {
                      // TODO: Показать меню опций чата
                      debugPrint('Chat options tapped');
                    },
                    icon: Icon(
                      Icons.more_vert,
                      color: context.dynamicPrimaryColor,
                      size: 22,
                    ),
                  ),
                  ),
                ),
              ],
            ),
        );
      },
    );
  }

  Widget _buildOnlineStatusIcon(BuildContext context) {
    final primaryColor = context.dynamicPrimaryColor;
    
    switch (onlineStatus.type) {
      case OnlineStatusType.online:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor, // Яркий акцентный цвет для онлайн
          ),
        );
      
      case OnlineStatusType.recent:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withValues(alpha: 0.7), // Потемнее для недавно
          ),
        );
      
      case OnlineStatusType.minutes:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: 12,
              color: primaryColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 2),
            Text(
              '${onlineStatus.value}м',
              style: AppTextStyles.body.copyWith(
                color: primaryColor.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        );
      
      case OnlineStatusType.hours:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.access_time,
              size: 12,
              color: primaryColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 2),
            Text(
              '${onlineStatus.value}ч',
              style: AppTextStyles.body.copyWith(
                color: primaryColor.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        );
      
      case OnlineStatusType.days:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 12,
              color: primaryColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 2),
            Text(
              '${onlineStatus.value}д',
              style: AppTextStyles.body.copyWith(
                color: primaryColor.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        );
      
      case OnlineStatusType.longAgo:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: primaryColor.withValues(alpha: 0.3), // Самый темный для давно
          ),
        );
      
      case OnlineStatusType.group:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group,
              size: 12,
              color: primaryColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 2),
            Text(
              '${onlineStatus.value}',
              style: AppTextStyles.body.copyWith(
                color: primaryColor.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildTypingIndicator(BuildContext context) {
    return _TypingIndicatorWidget();
  }
}

/// Виджет индикатора печати с анимацией
class _TypingIndicatorWidget extends StatefulWidget {
  @override
  State<_TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<_TypingIndicatorWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _controller.addListener(() {
      final value = _controller.value;
      final newDotCount = ((value * 3).floor() % 3) + 1;
      if (newDotCount != _dotCount) {
        setState(() {
          _dotCount = newDotCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.edit,
          size: 12,
          color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 20,
          child: Text(
            '.' * _dotCount,
            style: AppTextStyles.body.copyWith(
              color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
              fontSize: 16,
              height: 1,
            ),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }
}
