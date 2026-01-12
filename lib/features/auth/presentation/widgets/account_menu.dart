import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../theme/app_text_styles.dart';
import '../../../../routes/route_names.dart';
import '../../../../routes/app_router.dart';
import '../../../../core/widgets/authorized_cached_network_image.dart';
import '../blocs/account_bloc.dart';
import '../blocs/account_event.dart';
import '../blocs/account_state.dart';
import '../../domain/models/account.dart';

class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    // Загружаем аккаунты при первом построении
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accountBloc = context.read<AccountBloc>();
      if (accountBloc.state is AccountInitial) {
        accountBloc.add(LoadAccountsEvent());
      }
    });

    return BlocBuilder<AccountBloc, AccountState>(
      builder: (context, state) {
        if (state is AccountLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is AccountError) {
          return Center(
            child: Text(
              'Ошибка: ${state.message}',
              style: AppTextStyles.body.copyWith(color: Theme.of(context).colorScheme.onSurface),
            ),
          );
        }

        if (state is AccountLoaded) {
          return _buildMenu(context, state.accounts, state.activeAccount);
        }

        if (state is AccountSwitching) {
          return _buildSwitchingMenu(context, state.fromAccount, state.toAccount);
        }

        if (state is AccountSwitched) {
          return _buildMenu(context, [], state.activeAccount);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMenu(BuildContext context, List<Account> accounts, Account? activeAccount) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 3,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400, maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Аккаунты',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

            // Список аккаунтов
            if (accounts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Нет сохраненных аккаунтов',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: accounts.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    thickness: 1,
                    indent: 60,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    final isActive = account.id == activeAccount?.id;
                    return _buildAccountItem(context, account, isActive);
                  },
                ),
              ),

            // Разделитель перед кнопкой добавления
            if (accounts.isNotEmpty)
              Divider(
                height: 1,
                thickness: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),

            // Кнопка добавить аккаунт
            _buildAddAccountButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchingMenu(BuildContext context, Account? fromAccount, Account toAccount) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      elevation: 3,
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 400, maxWidth: 320),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.swap_horiz,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Переключение аккаунта',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Индикатор загрузки
            CircularProgressIndicator(
              color: colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Выполняется вход...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountItem(BuildContext context, Account account, bool isActive) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: isActive 
            ? colorScheme.primaryContainer 
            : colorScheme.surfaceContainerHighest,
        foregroundColor: isActive 
            ? colorScheme.onPrimaryContainer 
            : colorScheme.onSurfaceVariant,
        child: account.avatarUrl != null
            ? ClipOval(
                child: AuthorizedCachedNetworkImage(
                  imageUrl: account.avatarUrl!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  memCacheWidth: 40,
                  memCacheHeight: 40,
                  errorWidget: (context, url, error) => Icon(
                    Icons.person,
                    size: 20,
                  ),
                ),
              )
            : Icon(
                Icons.person,
                size: 20,
              ),
      ),
      title: Text(
        account.username,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: colorScheme.onSurface,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: isActive
          ? Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Активный',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : null,
      trailing: IconButton(
        icon: Icon(
          Icons.close,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        onPressed: () {
          _showDeleteConfirmation(context, account);
        },
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      onTap: () {
        if (!isActive) {
          context.read<AccountBloc>().add(SwitchAccountEvent(account));
          Navigator.of(context).pop();
        }
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      selected: isActive,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
    );
  }

  Widget _buildAddAccountButton(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        child: Icon(
          Icons.add,
          size: 20,
        ),
      ),
      title: Text(
        'Добавить аккаунт',
        style: theme.textTheme.bodyLarge?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        debugPrint('AccountMenu: Add account button pressed');
        Navigator.of(context).pop();
        Future.delayed(const Duration(milliseconds: 100), () {
          debugPrint('AccountMenu: Attempting navigation to AddAccountScreen');
          AppRouter.navigatorKey.currentState?.pushNamed(RouteNames.addAccount);
        });
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, Account account) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Удалить аккаунт',
          style: AppTextStyles.h2.copyWith(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Вы уверены, что хотите удалить аккаунт "${account.username}"? Все данные этого аккаунта будут потеряны.',
          style: AppTextStyles.body.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              'Отмена',
              style: AppTextStyles.button.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<AccountBloc>().add(RemoveAccountEvent(account.id));
              Navigator.of(dialogContext).pop();
            },
            child: Text(
              'Удалить',
              style: AppTextStyles.button.copyWith(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
