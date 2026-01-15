/// Компонент социальных ссылок профиля
///
/// Отображает социальные ссылки пользователя в виде компактных кнопок.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/models/social_link.dart';
import 'profile_subscription_badge.dart';

/// Виджет социальных ссылок
///
/// Горизонтальный список компактных кнопок для социальных сетей.
class ProfileSocialLinks extends StatelessWidget {
  final List<SocialLink> socials;
  final Color accentColor;
  final ColorScheme? profileColorScheme;
  final bool hasProfileBackground;
  final dynamic subscription; // Добавлено для отображения подписки

  const ProfileSocialLinks({
    super.key,
    required this.socials,
    required this.accentColor,
    this.profileColorScheme,
    this.hasProfileBackground = false,
    this.subscription,
  });

  IconData _getIconForSocial(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('instagram')) return Icons.camera_alt;
    if (lowerName.contains('twitter') || lowerName.contains('x.com')) return Icons.chat;
    if (lowerName.contains('telegram')) return Icons.telegram;
    if (lowerName.contains('vk')) return Icons.group;
    if (lowerName.contains('youtube')) return Icons.play_circle;
    if (lowerName.contains('tiktok')) return Icons.music_note;
    return Icons.link;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> children = [];

    // Добавляем карточку подписки в начало, если она активна
    if (subscription != null && subscription.active == true) {
      children.add(
        Container(
          decoration: BoxDecoration(
            color: hasProfileBackground
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                : (profileColorScheme?.surfaceContainerLow ?? Theme.of(context).colorScheme.surfaceContainerLow),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: profileColorScheme?.outline.withValues(alpha: 0.2) ?? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: ProfileSubscriptionBadge(
            subscription: subscription,
            accentColor: accentColor,
          ),
        ),
      );
    }

    // Добавляем социальные ссылки
    children.addAll(socials.map((social) {
      return InkWell(
        onTap: () => _launchUrl(social.link),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: hasProfileBackground
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                : (profileColorScheme?.surfaceContainerLow ?? Theme.of(context).colorScheme.surfaceContainerLow),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: profileColorScheme?.outline.withValues(alpha: 0.2) ?? Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconForSocial(social.name),
                size: 16,
                color: accentColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  social.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }));

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: children,
    );
  }
}
