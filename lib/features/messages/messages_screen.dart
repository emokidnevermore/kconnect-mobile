import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_event.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_state.dart';
import 'package:kconnect_mobile/features/messages/presentation/widgets/chat_tile.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/services/storage_service.dart';

/// Экран списка сообщений
///
/// Отображает список чатов пользователя с возможностью поиска,
/// обновления и перехода к конкретным чатам.
/// Поддерживает WebSocket подключение для получения новых сообщений.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    context.read<MessagesBloc>().add(ConnectWebSocketEvent());
    context.read<MessagesBloc>().add(LoadChatsEvent());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<MessagesBloc, MessagesState>(
      builder: (context, state) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.opaque,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  // Отступ сверху под хедер
                  const SizedBox(height: 44),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ValueListenableBuilder<String?>(
                      valueListenable: StorageService.appBackgroundPathNotifier,
                      builder: (context, backgroundPath, child) {
                        final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
                        final fillColor = hasBackground 
                            ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.3)
                            : Theme.of(context).colorScheme.surfaceContainerLow;
                        
                        return TextField(
                          controller: _searchController,
                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                          decoration: InputDecoration(
                            hintText: 'Поиск чатов...',
                            hintStyle: TextStyle(color: context.dynamicPrimaryColor.withValues(alpha: 0.8)),
                            prefixIcon: Icon(Icons.search, color: context.dynamicPrimaryColor),
                            filled: true,
                            fillColor: fillColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (query) {
                            context.read<MessagesBloc>().add(SearchChatsEvent(query));
                          },
                        );
                      },
                    ),
                  ),

                // Chat list
                Expanded(
                  child: state.status == MessagesStatus.loading && state.chats.isEmpty
                      ? Center(
                          child: CircularProgressIndicator(
                            color: context.dynamicPrimaryColor,
                          ),
                        )
                      : state.filteredChats.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    state.chats.isEmpty
                                        ? 'Нет чатов'
                                        : 'Чаты не найдены',
                                    style: AppTextStyles.body.copyWith(
                                      color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                context.read<MessagesBloc>().add(RefreshChatsEvent());
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                itemCount: state.filteredChats.length,
                                itemBuilder: (context, index) {
                                  final chat = state.filteredChats[index];
                                  return ChatTile(
                                    key: ValueKey(chat.id),
                                    chat: chat,
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}
