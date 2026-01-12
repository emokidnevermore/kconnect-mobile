import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/core/widgets/authorized_cached_network_image.dart';
import 'package:kconnect_mobile/core/constants.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_bloc.dart';
import 'package:kconnect_mobile/features/messages/presentation/blocs/messages_event.dart';
import 'package:kconnect_mobile/injection.dart';
import 'package:kconnect_mobile/services/users_service.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';

/// Экран создания чата
///
/// Позволяет создать персональный или групповой чат
class CreateChatScreen extends StatefulWidget {
  const CreateChatScreen({super.key});

  @override
  State<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends State<CreateChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();
  final UsersService _usersService = locator<UsersService>();
  Timer? _searchDebounceTimer;
  
  // Search state
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;
  
  // Selection state
  int? _selectedUserId;
  final Map<int, Map<String, dynamic>> _selectedUsers = {}; // userId -> user data
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userSearchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _tabController.dispose();
    _userSearchController.removeListener(_onSearchChanged);
    _userSearchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _userSearchController.text.trim();
    
    // Cancel previous timer
    _searchDebounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }
    
    // Debounce search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    
    try {
      final result = await _usersService.searchUsers(query, perPage: 20);
      final users = List<Map<String, dynamic>>.from(result['users'] ?? []);
      
      if (mounted) {
        setState(() {
          _searchResults = users;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = 'Ошибка поиска: ${e.toString()}';
          _isSearching = false;
          _searchResults = [];
        });
      }
    }
  }

  void _selectUser(Map<String, dynamic> user) {
    final userId = user['id'] as int;
    
    if (_tabController.index == 0) {
      // Personal chat - select single user
      setState(() {
        _selectedUserId = userId;
      });
    } else {
      // Group chat - add to selected users
      setState(() {
        _selectedUsers[userId] = user;
      });
    }
  }

  void _removeSelectedUser(int userId) {
    setState(() {
      _selectedUsers.remove(userId);
    });
  }

  void _createPersonalChat() {
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите пользователя'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    context.read<MessagesBloc>().add(
      CreateChatEvent(userId: _selectedUserId!),
    );

    Navigator.of(context).pop();
  }

  void _createGroupChat() {
    if (_groupNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите название группы'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Выберите хотя бы одного участника'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    context.read<MessagesBloc>().add(
      CreateGroupChatEvent(
        title: _groupNameController.text.trim(),
        userIds: _selectedUsers.keys.toList(),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Новый чат',
          style: AppTextStyles.h3.copyWith(
            color: context.dynamicPrimaryColor,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close,
            color: context.dynamicPrimaryColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: context.dynamicPrimaryColor,
          unselectedLabelColor: context.dynamicPrimaryColor.withValues(alpha: 0.6),
          indicatorColor: context.dynamicPrimaryColor,
          tabs: const [
            Tab(text: 'Личный чат'),
            Tab(text: 'Групповой чат'),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        behavior: HitTestBehavior.opaque,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPersonalChatTab(),
            _buildGroupChatTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalChatTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _userSearchController,
            decoration: InputDecoration(
              hintText: 'Поиск по username или имени',
              hintStyle: TextStyle(
                color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: context.dynamicPrimaryColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: context.dynamicPrimaryColor,
                ),
              ),
            ),
            style: AppTextStyles.body.copyWith(
              color: context.dynamicPrimaryColor,
            ),
          ),
        ),
        // Selected user indicator
        if (_selectedUserId != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildSelectedUserChip(_selectedUserId!, isPersonal: true),
          ),
          const SizedBox(height: 16),
        ],
        // Search results or empty state
        Expanded(
          child: _buildSearchResults(isPersonal: true),
        ),
        // Create button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: (_isCreating || _selectedUserId == null) ? null : _createPersonalChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.dynamicPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Создать чат',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupChatTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Название группы',
                style: AppTextStyles.body.copyWith(
                  color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _groupNameController,
                decoration: InputDecoration(
                  hintText: 'Введите название группы',
                  hintStyle: TextStyle(
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.dynamicPrimaryColor,
                    ),
                  ),
                ),
                style: AppTextStyles.body.copyWith(
                  color: context.dynamicPrimaryColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Участники',
                style: AppTextStyles.body.copyWith(
                  color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _userSearchController,
                decoration: InputDecoration(
                  hintText: 'Поиск пользователей',
                  hintStyle: TextStyle(
                    color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: context.dynamicPrimaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.dynamicPrimaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: context.dynamicPrimaryColor,
                    ),
                  ),
                ),
                style: AppTextStyles.body.copyWith(
                  color: context.dynamicPrimaryColor,
                ),
              ),
            ],
          ),
        ),
        // Selected users chips
        if (_selectedUsers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedUsers.values.map((user) {
                final userId = user['id'] as int;
                return _buildSelectedUserChip(userId, isPersonal: false);
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // Search results
        Expanded(
          child: _buildSearchResults(isPersonal: false),
        ),
        // Create button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: (_isCreating || _selectedUsers.isEmpty || _groupNameController.text.trim().isEmpty) ? null : _createGroupChat,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.dynamicPrimaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
            child: _isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Создать группу',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults({required bool isPersonal}) {
    if (_isSearching) {
      return Center(
        child: CircularProgressIndicator(
          color: context.dynamicPrimaryColor,
        ),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _searchError!,
            style: AppTextStyles.bodySecondary.copyWith(
              color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_userSearchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPersonal ? Icons.person_search : Icons.group_add,
              size: 48,
              color: context.dynamicPrimaryColor.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              isPersonal ? 'Поиск пользователей' : 'Поиск участников',
              style: AppTextStyles.body.copyWith(
                color: context.dynamicPrimaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPersonal
                  ? 'Введите username или имя пользователя для поиска'
                  : 'Введите username или имя пользователя для добавления в группу',
              style: AppTextStyles.bodySecondary.copyWith(
                color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          'Пользователи не найдены',
          style: AppTextStyles.bodySecondary.copyWith(
            color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final userId = user['id'] as int;
        final isSelected = isPersonal
            ? _selectedUserId == userId
            : _selectedUsers.containsKey(userId);
        
        return _buildUserListItem(user, isSelected, isPersonal: isPersonal);
      },
    );
  }

  Widget _buildUserListItem(Map<String, dynamic> user, bool isSelected, {required bool isPersonal}) {
    final userId = user['id'] as int;
    final name = user['name'] as String? ?? '';
    final username = user['username'] as String? ?? '';
    final avatarUrl = user['avatar_url'] as String?;
    final isVerified = user['is_verified'] == true;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? context.dynamicPrimaryColor.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.dynamicPrimaryColor.withValues(alpha: 0.2),
          ),
          child: ClipOval(
            child: AuthorizedCachedNetworkImage(
              imageUrl: avatarUrl ?? AppConstants.userAvatarPlaceholder,
              fit: BoxFit.cover,
              placeholder: (context, url) => Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.dynamicPrimaryColor,
                ),
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.person,
                color: context.dynamicPrimaryColor,
                size: 24,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name.isNotEmpty ? name : username,
                style: AppTextStyles.body.copyWith(
                  color: context.dynamicPrimaryColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.verified,
                size: 16,
                color: context.dynamicPrimaryColor,
              ),
            ],
          ],
        ),
        subtitle: username.isNotEmpty && name != username
            ? Text(
                '@$username',
                style: AppTextStyles.bodySecondary.copyWith(
                  color: context.dynamicPrimaryColor.withValues(alpha: 0.7),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: isSelected
            ? Icon(
                Icons.check_circle,
                color: context.dynamicPrimaryColor,
              )
            : null,
        onTap: () {
          if (isPersonal) {
            // For personal chat, always select (toggle)
            if (_selectedUserId == userId) {
              setState(() {
                _selectedUserId = null;
              });
            } else {
              _selectUser(user);
            }
          } else {
            // For group chat, toggle selection
            if (_selectedUsers.containsKey(userId)) {
              _removeSelectedUser(userId);
            } else {
              _selectUser(user);
            }
          }
        },
      ),
    );
  }

  Widget _buildSelectedUserChip(int userId, {required bool isPersonal}) {
    final user = isPersonal
        ? _searchResults.firstWhere((u) => u['id'] == userId, orElse: () => {})
        : _selectedUsers[userId];
    
    if (user == null || user.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final name = user['name'] as String? ?? '';
    final username = user['username'] as String? ?? '';
    final displayName = name.isNotEmpty ? name : username;
    
    return Chip(
      avatar: CircleAvatar(
        radius: 12,
        backgroundColor: context.dynamicPrimaryColor.withValues(alpha: 0.2),
        child: ClipOval(
          child: AuthorizedCachedNetworkImage(
            imageUrl: (user['avatar_url'] as String?) ?? AppConstants.userAvatarPlaceholder,
            width: 24,
            height: 24,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => Icon(
              Icons.person,
              size: 12,
              color: context.dynamicPrimaryColor,
            ),
          ),
        ),
      ),
      label: Text(
        displayName,
        style: TextStyle(
          color: context.dynamicPrimaryColor,
          fontSize: 12,
        ),
      ),
      onDeleted: isPersonal
          ? null
          : () {
              _removeSelectedUser(userId);
            },
      backgroundColor: context.dynamicPrimaryColor.withValues(alpha: 0.1),
      deleteIcon: Icon(
        Icons.close,
        size: 16,
        color: context.dynamicPrimaryColor,
      ),
    );
  }
}
