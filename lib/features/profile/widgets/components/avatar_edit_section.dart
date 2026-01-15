/// Компонент редактирования аватара профиля
///
/// Позволяет пользователю выбрать и изменить аватар профиля.
/// Использует MediaPickerModal для выбора изображения.
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:kconnect_mobile/core/constants.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/core/widgets/authorized_cached_network_image.dart';
import 'package:kconnect_mobile/services/storage_service.dart';

/// Виджет секции редактирования аватара
class AvatarEditSection extends StatelessWidget {
  final String? selectedAvatarUrl;
  final VoidCallback onPickAvatar;
  final VoidCallback? onDeleteAvatar;

  const AvatarEditSection({
    super.key,
    required this.selectedAvatarUrl,
    required this.onPickAvatar,
    this.onDeleteAvatar,
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
                  'Аватар',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Аватар слева
                    Column(
                      children: [
                        GestureDetector(
                          onTap: onPickAvatar,
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).colorScheme.surface,
                                ),
                                child: ClipOval(
                                  child: selectedAvatarUrl != null && selectedAvatarUrl!.isNotEmpty
                                      ? (selectedAvatarUrl!.startsWith('http')
                                          ? AuthorizedCachedNetworkImage(
                                              imageUrl: selectedAvatarUrl!,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                              errorWidget: (context, url, error) => CachedNetworkImage(
                                                imageUrl: AppConstants.userAvatarPlaceholder,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                                errorWidget: (context, url, error) => Stack(
                                                  fit: StackFit.expand,
                                                  alignment: Alignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.person,
                                                      size: 60,
                                                      color: Colors.grey,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Image.file(
                                              File(selectedAvatarUrl!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => CachedNetworkImage(
                                                imageUrl: AppConstants.userAvatarPlaceholder,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                                errorWidget: (context, url, error) => Stack(
                                                  fit: StackFit.expand,
                                                  alignment: Alignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.person,
                                                      size: 60,
                                                      color: Colors.grey,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ))
                                      : CachedNetworkImage(
                                          imageUrl: AppConstants.userAvatarPlaceholder,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                          errorWidget: (context, url, error) => Stack(
                                            fit: StackFit.expand,
                                            alignment: Alignment.center,
                                            children: [
                                              const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.grey,
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                      ],
                    ),
                    const SizedBox(width: 20),
                    // Кнопка удаления и информация справа
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Кнопка удаления аватара
                          if (selectedAvatarUrl != null && selectedAvatarUrl!.isNotEmpty && onDeleteAvatar != null)
                            TextButton.icon(
                              onPressed: onDeleteAvatar,
                              icon: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.error,
                                size: 18,
                              ),
                              label: Text(
                                'Удалить аватар',
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
                          if (selectedAvatarUrl != null && selectedAvatarUrl!.isNotEmpty && onDeleteAvatar != null)
                            const SizedBox(height: 12),
                          // Информация о форматах и размере
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Форматы: JPG, PNG, GIF',
                                  style: AppTextStyles.bodySecondary.copyWith(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Максимальный размер: 5 МБ',
                                  style: AppTextStyles.bodySecondary.copyWith(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
