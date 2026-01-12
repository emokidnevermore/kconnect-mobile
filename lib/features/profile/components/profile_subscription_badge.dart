/// Компонент бейджа подписки профиля
///
/// Отображает индикатор активной подписки пользователя.
library;

import 'package:flutter/material.dart';
import '../domain/models/subscription_info.dart';

/// Виджет бейджа подписки
///
/// Компактный чип для отображения статуса подписки.
class ProfileSubscriptionBadge extends StatelessWidget {
  final SubscriptionInfo subscription;
  final Color accentColor;

  const ProfileSubscriptionBadge({
    super.key,
    required this.subscription,
    required this.accentColor,
  });

  String get _subscriptionLabel {
    if (subscription.isLifetime) {
      return 'Навсегда';
    }
    if (subscription.type == 'max') {
      return 'MAX';
    }
    return subscription.type.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            subscription.isLifetime ? Icons.all_inclusive : Icons.star,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 6),
          Text(
            _subscriptionLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
