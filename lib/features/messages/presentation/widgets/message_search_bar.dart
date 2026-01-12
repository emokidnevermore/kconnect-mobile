import 'package:flutter/material.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';

/// Виджет поисковой строки для сообщений в чате
///
/// Отображает поле ввода для поиска по сообщениям
class MessageSearchBar extends StatefulWidget {
  final Function(String) onSearchChanged;
  final VoidCallback? onClose;
  final String? initialQuery;

  const MessageSearchBar({
    super.key,
    required this.onSearchChanged,
    this.onClose,
    this.initialQuery,
  });

  @override
  State<MessageSearchBar> createState() => _MessageSearchBarState();
}

class _MessageSearchBarState extends State<MessageSearchBar> {
  late TextEditingController _searchController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _searchController.addListener(_onSearchChanged);
    
    // Auto-focus search field when opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    widget.onSearchChanged(_searchController.text);
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    // Listen to text changes for clear button visibility
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _searchController,
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          bottom: BorderSide(
            color: context.dynamicPrimaryColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Поиск по сообщениям...',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: AppTextStyles.body.copyWith(
                    color: context.dynamicPrimaryColor,
                  ),
                  onSubmitted: (value) {
                    // Search on enter
                    widget.onSearchChanged(value);
                  },
                ),
              ),
              if (value.text.isNotEmpty)
                IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  onPressed: _clearSearch,
                ),
              if (widget.onClose != null)
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                    size: 20,
                  ),
                  onPressed: widget.onClose,
                ),
            ],
          ),
        );
      },
    );
  }
}
