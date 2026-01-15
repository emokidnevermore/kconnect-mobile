/// Компонент редактирования фона профиля
///
/// Позволяет пользователям с подпиской выбрать и изменить фоновое изображение профиля.
/// Использует MediaPickerModal для выбора изображения.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import 'package:kconnect_mobile/features/profile/domain/models/subscription_info.dart';
import 'package:kconnect_mobile/core/widgets/authorized_cached_network_image.dart';

/// Виджет секции редактирования фона профиля
class ProfileBackgroundEditSection extends StatelessWidget {
  final String? selectedProfileBackgroundUrl;
  final VoidCallback onPickProfileBackground;
  final VoidCallback? onDeleteProfileBackground;
  final SubscriptionInfo? subscription;

  const ProfileBackgroundEditSection({
    super.key,
    required this.selectedProfileBackgroundUrl,
    required this.onPickProfileBackground,
    this.onDeleteProfileBackground,
    this.subscription,
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

        // Проверка подписки Ultimate или MAX
        final hasRequiredSubscription = subscription?.active == true &&
            (subscription?.type.toLowerCase() == 'ultimate' || subscription?.type.toLowerCase() == 'max');

        return Card(
          color: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Фон профиля',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                // Если есть подписка Ultimate или MAX, показываем элементы управления
                if (hasRequiredSubscription) ...[
                  InkWell(
                    onTap: onPickProfileBackground,
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 1.0, // Квадратное соотношение сторон
                      child: Container(
                        width: double.infinity, // Растягивается по всей ширине
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          image: null, // Will be handled by the FutureBuilder below
                        ),
                        child: selectedProfileBackgroundUrl == null
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.wallpaper,
                                      size: 24,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Выбрать фон',
                                      style: AppTextStyles.bodySecondary.copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                    child: selectedProfileBackgroundUrl!.startsWith('http')
                                          ? AuthorizedCachedNetworkImage(
                                              key: ValueKey(selectedProfileBackgroundUrl),
                                              imageUrl: selectedProfileBackgroundUrl!,
                                              fit: BoxFit.cover,
                                              useOldImageOnUrlChange: false,
                                              placeholder: (context, url) => Container(
                                                color: Theme.of(context).colorScheme.surface,
                                                child: const Center(child: CircularProgressIndicator()),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                color: Theme.of(context).colorScheme.surface,
                                                child: const Center(
                                                  child: Icon(Icons.error),
                                                ),
                                              ),
                                            )
                                          : Image.file(
                                              File(selectedProfileBackgroundUrl!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: Theme.of(context).colorScheme.surface,
                                                child: const Center(
                                                  child: Icon(Icons.error),
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.edit,
                                        color: Theme.of(context).colorScheme.onPrimary,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Кнопка удаления фона профиля
                  if (selectedProfileBackgroundUrl != null && selectedProfileBackgroundUrl!.isNotEmpty && onDeleteProfileBackground != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: onDeleteProfileBackground,
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                          size: 18,
                        ),
                        label: Text(
                          'Удалить фон',
                          style: AppTextStyles.body.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 14,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          backgroundColor: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  // Информация о размерах и форматах
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'PNG, JPG, GIF. До 5MB.',
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ] else ...[
                  // Если нет подписки, показываем сообщение
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.workspace_premium,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Доступно только для подписки',
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ultimate или MAX',
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
