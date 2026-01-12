import 'package:flutter/material.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/core/widgets/authorized_cached_network_image.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';

/// Виджет выбора стикеров
///
/// Отображает панель со стикерами для отправки
class StickerPicker extends StatefulWidget {
  final Function(String stickerId, String? stickerUrl) onStickerSelected;
  
  const StickerPicker({
    super.key,
    required this.onStickerSelected,
  });

  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker> {
  // TODO: Load stickers from API
  // For now, using placeholder stickers
  final List<_StickerPack> _stickerPacks = [
    _StickerPack(
      id: 1,
      name: 'Эмодзи',
      stickers: [
        _Sticker(id: 1, packId: 1, url: null, content: '[STICKER_1_1]'),
        _Sticker(id: 2, packId: 1, url: null, content: '[STICKER_1_2]'),
        _Sticker(id: 3, packId: 1, url: null, content: '[STICKER_1_3]'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: context.dynamicPrimaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Tab bar for sticker packs
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _stickerPacks.length,
              itemBuilder: (context, index) {
                final pack = _stickerPacks[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Chip(
                    label: Text(
                      pack.name,
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: context.dynamicPrimaryColor,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: context.dynamicPrimaryColor.withValues(alpha: 0.1),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Sticker grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _stickerPacks.first.stickers.length,
              itemBuilder: (context, index) {
                final sticker = _stickerPacks.first.stickers[index];
                return GestureDetector(
                  onTap: () {
                    widget.onStickerSelected(sticker.content, sticker.url);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.dynamicPrimaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: sticker.url != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AuthorizedCachedNetworkImage(
                              imageUrl: sticker.url!,
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  color: context.dynamicPrimaryColor,
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) => Icon(
                                Icons.tag_faces,
                                color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              '🎴',
                              style: TextStyle(fontSize: 32),
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StickerPack {
  final int id;
  final String name;
  final List<_Sticker> stickers;

  _StickerPack({
    required this.id,
    required this.name,
    required this.stickers,
  });
}

class _Sticker {
  final int id;
  final int packId;
  final String? url;
  final String content; // Format: [STICKER_packId_stickerId]

  _Sticker({
    required this.id,
    required this.packId,
    this.url,
    required this.content,
  });
}
