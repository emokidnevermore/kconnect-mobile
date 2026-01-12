/// Секция уведомлений с анимированным раскрытием
///
/// Отображает панель уведомлений с blur эффектом фона.
/// Поддерживает swipe-to-dismiss и pull-to-refresh.
/// Показывает список уведомлений с различными типами иконок.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/core/utils/date_format.dart';
import 'package:kconnect_mobile/core/widgets/staggered_list_item.dart';
import 'package:kconnect_mobile/core/widgets/custom_refresh_indicator.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/core/widgets/authorized_cached_network_image.dart';
import 'package:kconnect_mobile/features/profile/components/swipe_pop_container.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';

import '../../data/models/notification_model.dart';
import '../bloc/notifications_bloc.dart';
import '../bloc/notifications_event.dart';
import '../bloc/notifications_state.dart';

/// Виджет секции уведомлений с анимацией
///
/// Создает полноэкранную панель уведомлений с blur эффектом.
/// Поддерживает различные взаимодействия: swipe, dismiss, refresh.
class NotificationsSection extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onClose;

  const NotificationsSection({
    super.key,
    required this.isVisible,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300), // Material 3 standard duration
      switchInCurve: Curves.easeOutCubic, // Material 3 emphasized easing
      switchOutCurve: Curves.decelerate, // Material 3 decelerate easing
      child: isVisible
          ? Stack(
              children: [
                // Панель с blur эффектом
                SwipePopContainer(
                  onPop: onClose,
                  child: _NotificationsPanel(onClose: onClose),
                ),
                // Хедер полностью вне панели (вне blur эффекта)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: _NotificationsHeader(onClose: onClose),
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

class _NotificationsPanel extends StatelessWidget {
  final VoidCallback onClose;

  const _NotificationsPanel({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(16),
        bottomRight: Radius.circular(16),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: DefaultTextStyle(
            style: theme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface) ?? TextStyle(color: Theme.of(context).colorScheme.onSurface),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
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
                              style: theme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant) ??
                                  TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          );
                        }

                        return CustomRefreshIndicator(
                          onRefresh: () async {
                            context.read<NotificationsBloc>().add(const NotificationsRefreshed());
                          },
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemBuilder: (context, index) {
                              final item = state.notifications[index];
                              return StaggeredListItem(
                                index: index,
                                child: _NotificationTile(item: item, theme: theme, onClose: onClose),
                              );
                            },
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemCount: state.notifications.length,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
  }
}

class _NotificationTile extends StatefulWidget {
  final NotificationItem item;
  final TextTheme? theme;
  final VoidCallback onClose;

  const _NotificationTile({required this.item, this.theme, required this.onClose});

  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  double _startX = 0;
  double _startY = 0;
  double _currentX = 0;
  double _currentY = 0;
  bool _isTrackingSwipe = false;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<NotificationsBloc>();

    final backgroundColor = widget.item.isRead
        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.6)
        : context.dynamicPrimaryColor.withValues(alpha: 0.12);
    final icon = _notificationIcon(widget.item.type, widget.item.contentType);

    return Listener(
      onPointerDown: (details) {
        _startX = details.position.dx;
        _startY = details.position.dy;
        _currentX = _startX;
        _currentY = _startY;
        _isTrackingSwipe = true;
      },
      onPointerMove: (details) {
        if (_isTrackingSwipe) {
          _currentX = details.position.dx;
          _currentY = details.position.dy;
        }
      },
      onPointerUp: (details) {
        if (_isTrackingSwipe) {
          final deltaX = _currentX - _startX;
          final deltaY = _currentY - _startY;
          final velocity = details.delta.dx; // Approximate velocity

          final isSwipeRight = deltaX > 30; // Minimum swipe distance
          final isFastSwipe = velocity > 5; // Minimum velocity
          final isMostlyHorizontal = deltaX.abs() > deltaY.abs() * 0.7; // Horizontal movement dominates

          if ((isSwipeRight || isFastSwipe) && isMostlyHorizontal) {
            widget.onClose();
          }

          _isTrackingSwipe = false;
        }
      },
      child: Dismissible(
        key: ValueKey('notif-${widget.item.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) async {
          bloc.add(NotificationReadRequested(widget.item.id));
          return false;
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
              Text('Отметить прочитанным', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              SizedBox(width: 8),
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
              _Avatar(avatarUrl: widget.item.senderUser?.avatarUrl),
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
                                  _buildTitle(widget.item),
                                  style: (widget.theme?.titleSmall ?? const TextStyle()).copyWith(
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
                          formatNotificationDate(widget.item.createdAt),
                          style: (widget.theme?.bodySmall ?? const TextStyle()).copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.item.message,
                      style: (widget.theme?.bodyMedium ?? const TextStyle()).copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    if (widget.item.commentContent != null && widget.item.commentContent!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _PreviewChip(text: widget.item.commentContent!),
                    ] else if (widget.item.postContent != null && widget.item.postContent!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _PreviewChip(text: widget.item.postContent!),
                    ]
                  ],
                ),
              ),
            ],
          ),
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

/// Хедер панели уведомлений в стиле AppHeader
class _NotificationsHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _NotificationsHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.transparent,
      child: Row(
        children: [
          // Логотип и название "Уведомления" в отдельной карточке
          Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
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
          ),
          const Spacer(),
          // Кнопка закрытия в отдельной карточке
          Card(
            margin: EdgeInsets.zero,
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onClose,
                icon: Icon(
                  Icons.close,
                  color: context.dynamicPrimaryColor,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
