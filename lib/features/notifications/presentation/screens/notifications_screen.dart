/// Экран уведомлений
///
/// Полноэкранный интерфейс для просмотра уведомлений.
/// Показывает список уведомлений с различными типами иконок.
/// Поддерживает pull-to-refresh и swipe-to-dismiss.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/core/utils/date_format.dart';
import 'package:kconnect_mobile/core/widgets/staggered_list_item.dart';
import 'package:kconnect_mobile/core/widgets/custom_refresh_indicator.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/core/widgets/authorized_cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/core/widgets/app_background.dart';
import 'package:kconnect_mobile/services/storage_service.dart';

import '../../data/models/notification_model.dart';
import '../bloc/notifications_bloc.dart';
import '../bloc/notifications_event.dart';
import '../bloc/notifications_state.dart';

/// Экран уведомлений
///
/// Полноэкранный интерфейс для просмотра уведомлений.
/// Показывает список уведомлений с различными типами иконок.
/// Поддерживает pull-to-refresh и swipe-to-dismiss.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // AppBackground as bottom layer
        AppBackground(fallbackColor: Theme.of(context).colorScheme.surface),

        // Main content
        Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // Content
              SafeArea(
                bottom: true,
                child: BlocBuilder<NotificationsBloc, NotificationsState>(
                  builder: (context, state) {
                    if (state.status == NotificationsStatus.loading) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (state.notifications.isEmpty) {
                      return Center(
                        child: Text(
                          'Нет уведомлений',
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return CustomRefreshIndicator(
                      onRefresh: () async {
                        context.read<NotificationsBloc>().add(const NotificationsRefreshed());
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 72, 16, 16), // Top padding for header
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final item = state.notifications[index];
                          return StaggeredListItem(
                            index: index,
                            child: _NotificationTile(item: item),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemCount: state.notifications.length,
                      ),
                    );
                  },
                ),
              ),

              // Header positioned above content (like in main_tabs.dart)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    height: 56,
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
                    child: Row(
                      children: [
                        ValueListenableBuilder<String?>(
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
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      'lib/assets/icons/logo.svg',
                                      height: 20,
                                      width: 20,
                                      colorFilter: ColorFilter.mode(context.dynamicPrimaryColor, BlendMode.srcIn),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Уведомления',
                                      style: AppTextStyles.postAuthor.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const Spacer(),
                        ValueListenableBuilder<String?>(
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
                                padding: const EdgeInsets.all(4),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: Icon(
                                    Icons.close,
                                    color: context.dynamicPrimaryColor,
                                    size: 22,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;

  const _NotificationTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NotificationsBloc>();

    final backgroundColor = item.isRead
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.6)
        : context.dynamicPrimaryColor.withValues(alpha: 0.12);
    final icon = _notificationIcon(item.type, item.contentType);

    return Dismissible(
      key: ValueKey('notif-${item.id}'),
      direction: DismissDirection.endToStart, // Only left swipe
      confirmDismiss: (_) async {
        bloc.add(NotificationReadRequested(item.id));
        return false; // Don't dismiss the item, just mark as read
      },
      background: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Отметить прочитанным',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(width: 8),
            Icon(Icons.check_circle, color: Theme.of(context).colorScheme.onSurface),
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.08),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(avatarUrl: item.senderUser?.avatarUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (icon != null) ...[
                              Icon(icon, size: 16, color: context.dynamicPrimaryColor),
                              const SizedBox(width: 6),
                            ],
                            Expanded(
                              child: Text(
                                _buildTitle(item),
                                style: AppTextStyles.body.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatNotificationDate(item.createdAt),
                        style: AppTextStyles.bodySecondary.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (item.commentContent != null && item.commentContent!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _PreviewChip(text: item.commentContent!),
                  ] else if (item.postContent != null && item.postContent!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _PreviewChip(text: item.postContent!),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildTitle(NotificationItem item) {
    if (item.senderUser != null && item.senderUser!.name.isNotEmpty) {
      return item.senderUser!.name;
    }
    return item.type;
  }

  IconData? _notificationIcon(String type, String contentType) {
    switch (type) {
      case 'post_like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment;
      case 'follow':
        return Icons.person_add;
      case 'gift_received':
        return Icons.card_giftcard;
      default:
        if (contentType == 'comment') return Icons.comment_outlined;
        if (contentType == 'post') return Icons.favorite_border;
        return null;
    }
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;

  const _Avatar({this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
        ),
        child: Icon(
          Icons.notifications_outlined,
          color: Theme.of(context).colorScheme.onSurface,
          size: 20,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AuthorizedCachedNetworkImage(
        imageUrl: avatarUrl!,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        memCacheWidth: 80,
        memCacheHeight: 80,
        errorWidget: (_, _, _) {
          return Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
            ),
            child: Icon(
              Icons.notifications_outlined,
              color: Theme.of(context).colorScheme.onSurface,
              size: 20,
            ),
          );
        },
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final String text;

  const _PreviewChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
    );
  }
}
