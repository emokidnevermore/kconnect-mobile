/// Экран редактирования профиля пользователя
///
/// Полноэкранный интерфейс для редактирования всех аспектов профиля:
/// аватар, обложка, статус, имя, описание, цвет профиля и т.д.
/// Использует анимации аналогично полноэкранному поиску музыки.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:kconnect_mobile/features/profile/domain/models/user_profile.dart';
import 'package:kconnect_mobile/features/profile/domain/models/social_link.dart';
import 'package:kconnect_mobile/features/profile/domain/models/achievement_info.dart';
import 'package:kconnect_mobile/features/profile/domain/models/subscription_info.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_bloc.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_event.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_state.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_event.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_state.dart';
import 'package:kconnect_mobile/core/theme/presentation/blocs/theme_bloc.dart';
import 'package:kconnect_mobile/core/theme/presentation/blocs/theme_event.dart';
import 'package:kconnect_mobile/core/theme/presentation/blocs/theme_state.dart';
import 'package:kconnect_mobile/services/storage_service.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/core/widgets/app_background.dart';
import 'package:kconnect_mobile/services/api_client/dio_client.dart';
import 'package:kconnect_mobile/shared/widgets/media_picker_modal.dart';
import 'package:kconnect_mobile/features/profile/widgets/components/avatar_edit_section.dart';
import 'package:kconnect_mobile/features/profile/widgets/components/cover_edit_section.dart';
import 'package:kconnect_mobile/features/profile/widgets/components/name_edit_section.dart';
import 'package:kconnect_mobile/features/profile/widgets/components/username_edit_section.dart';
import 'package:kconnect_mobile/features/profile/widgets/components/description_edit_section.dart';
import 'package:kconnect_mobile/features/profile/widgets/components/status_edit_section.dart';
import 'package:kconnect_mobile/features/profile/widgets/components/accent_color_edit_section.dart';
import 'package:kconnect_mobile/features/profile/widgets/components/profile_background_edit_section.dart';
import 'package:kconnect_mobile/shared/widgets/color_picker_dialog.dart' as color_picker;
import '../../../shared/widgets/saving_overlay.dart';

enum SavingState {
  idle,
  saving,
  success,
  error,
}

/// Виджет полноэкранного редактирования профиля
///
/// Анимируется аналогично FullScreenSearch с fade и slide up эффектами.
/// Предоставляет интерфейс для редактирования всех полей профиля.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideUpAnimation;

  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();

  // Current values
  String? _selectedAvatarUrl;
  String? _selectedBannerUrl;
  String? _selectedProfileBackgroundUrl;
  String? _selectedProfileColor;
  String? _selectedStatusText;
  String? _selectedStatusColor;

  // Track changes
  final Set<String> _changedFields = {};

  // bool _isLoading = true; // Not used - fetchProfileData handles loading
  // String? _errorMessage; // Not used - errors are handled via state
  UserProfile? _profile;

  // Saving states
  SavingState _savingState = SavingState.idle;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _slideUpAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Start animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      // Fetch profile data after animation starts
      _fetchProfileData();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _descriptionController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  void _onFieldChanged(String field) {
    setState(() {
      _changedFields.add(field);
    });
  }

  bool get _hasUnsavedChanges {
    if (_profile == null) return false;

    // Check text field changes
    if (_changedFields.isNotEmpty) return true;

    // Check media field changes
    if (_selectedAvatarUrl != _profile!.avatarUrl) return true;
    if (_selectedBannerUrl != _profile!.bannerUrl) return true;
    if (_selectedProfileBackgroundUrl != _profile!.profileBackgroundUrl) return true;
    if (_selectedProfileColor != _profile!.profileColor) return true;

    // Check status changes (both text and color)
    if (_selectedStatusText != _profile!.statusText) return true;
    if (_selectedStatusColor != _profile!.statusColor) return true;

    return false;
  }

  Future<void> _fetchProfileData() async {
    try {
      // Loading state is handled by the profile state management

      // Get current username from auth state to fetch profile
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        throw Exception('Пользователь не авторизован');
      }

      final username = authState.user.username;

      // Fetch profile data directly from API
      final response = await DioClient().get('/api/profile/$username');

      if (response.statusCode == 200) {
        final data = response.data;
        final userData = data['user'] as Map<String, dynamic>;

        // Create UserProfile from API response - handle the /api/profile response structure
        final profile = UserProfile(
          id: userData['id'] ?? 0,
          name: userData['name'] ?? '',
          username: userData['username'] ?? '',
          about: userData['about']?.toString(),
          photo: userData['photo']?.toString(),
          coverPhoto: userData['cover_photo']?.toString(),
          statusText: userData['status_text']?.toString(),
          statusColor: userData['status_color']?.toString(),
          avatarUrl: userData['avatar_url']?.toString(),
          bannerUrl: userData['banner_url']?.toString(),
          profileBackgroundUrl: userData['profile_background_url']?.toString(),
          profileColor: userData['profile_color']?.toString(),
          socials: (data['socials'] as List<dynamic>? ?? []).map((social) {
            return SocialLink.fromJson(social as Map<String, dynamic>);
          }).toList(),
          followersCount: data['followers_count'] ?? 0,
          followingCount: data['following_count'] ?? 0,
          friendsCount: data['friends_count'] ?? 0,
          postsCount: data['posts_count'] ?? 0,
          photosCount: data['photos_count'] ?? 0,
          // Fill in other required fields with proper type conversion
          verificationStatus: userData['verification_status']?.toString() ?? 'none',
          scam: userData['scam'] == 1 || userData['scam'] == true,
          accountType: userData['account_type']?.toString() ?? 'user',
          elementConnected: userData['element_connected'] == 1 || userData['element_connected'] == true,
          registrationDate: DateTime.parse(userData['registration_date']?.toString() ?? DateTime.now().toIso8601String()),
          interests: userData['interests'] is List<dynamic>
              ? List<String>.from(userData['interests'])
              : [userData['interests']?.toString() ?? ''],
          purchasedUsernames: [],
          connectInfo: [],
          equippedItems: [],
          // Optional fields
          verification: null,
          achievement: data['achievement'] != null ? AchievementInfo.fromJson(data['achievement']) : null,
          subscription: data['subscription'] != null ? SubscriptionInfo.fromJson(data['subscription']) : null,
          currentUserIsModerator: data['current_user_is_moderator'] == 1 || data['current_user_is_moderator'] == true,
          ban: data['ban'],
          // Relationship status from API
          isFollowing: data['is_following'] == 1 || data['is_following'] == true,
          isFriend: data['is_friend'] == 1 || data['is_friend'] == true,
          notificationsEnabled: data['notifications_enabled'] == 1 || data['notifications_enabled'] == true,
        );

        setState(() {
          _profile = profile;
        });

        // Initialize form fields with loaded data
        _nameController.text = profile.name;
        _usernameController.text = profile.username;
        _descriptionController.text = profile.about ?? '';
        _statusController.text = profile.statusText ?? '';

        _selectedAvatarUrl = profile.avatarUrl;
        _selectedBannerUrl = profile.bannerUrl;
        _selectedProfileBackgroundUrl = profile.profileBackgroundUrl;
        _selectedProfileColor = profile.profileColor;
        _selectedStatusText = profile.statusText;
        _selectedStatusColor = profile.statusColor;

        // Add listeners to track changes AFTER initialization to avoid false positives
        _nameController.addListener(() => _onFieldChanged('name'));
        _usernameController.addListener(() => _onFieldChanged('username'));
        _descriptionController.addListener(() => _onFieldChanged('about'));
        _statusController.addListener(() => _onFieldChanged('status'));
      } else {
        throw Exception('Ошибка загрузки профиля: ${response.statusCode}');
      }
    } catch (e) {
      // Error handled by the profile state management
    }
  }

  Future<void> _saveProfile() async {
    if (_savingState != SavingState.idle || _profile == null || !_hasUnsavedChanges) return;

    setState(() {
      _savingState = SavingState.saving;
    });

    try {
      // Collect all changes that need to be saved
      final updatesToPerform = <Future<void>>[];

      // Prepare values
      final name = _nameController.text.trim();
      final username = _usernameController.text.trim();
      final about = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
      final statusText = _statusController.text.trim().isEmpty ? null : _statusController.text.trim();

      // Update name if changed
      if (_changedFields.contains('name') && name != _profile!.name) {
        if (name.isEmpty) {
          // Don't allow empty name
          setState(() {
            _savingState = SavingState.idle;
          });
          return;
        }
        final nameUpdated = await _updateName(name);
        if (!nameUpdated) {
          // Handle error - could show message to user
          setState(() {
            _savingState = SavingState.idle;
          });
          return;
        }
      }

      // Update username if changed
      if (_changedFields.contains('username') && username != _profile!.username) {
        if (username.isEmpty || username.contains(' ')) {
          // Don't allow empty username or username with spaces
          setState(() {
            _savingState = SavingState.idle;
          });
          return;
        }
        final usernameUpdated = await _updateUsername(username);
        if (!usernameUpdated) {
          // Handle error - could show message to user
          setState(() {
            _savingState = SavingState.idle;
          });
          return;
        } else {
          // Update AuthBloc with new username
          if (mounted) {
            context.read<AuthBloc>().add(UpdateUsernameEvent(username));
          }
        }
      }

      // Update about if changed
      if (_changedFields.contains('about') && (about ?? '') != (_profile!.about ?? '')) {
        final aboutUpdated = await _updateAbout(about ?? '');
        if (!aboutUpdated) {
          // Handle error - could show message to user
          setState(() {
            _savingState = SavingState.idle;
          });
          return;
        }
      }

      // Update status if changed (text or color)
      if (_changedFields.contains('status') ||
          _selectedStatusText != _profile!.statusText ||
          _selectedStatusColor != _profile!.statusColor) {
        if (statusText != (_profile!.statusText ?? '') ||
            (_selectedStatusColor ?? 'FFFFFF') != (_profile!.statusColor ?? 'FFFFFF')) {
          final statusUpdated = await _updateStatus(statusText ?? '', _selectedStatusColor ?? 'FFFFFF');
          if (!statusUpdated) {
            setState(() {
              _savingState = SavingState.idle;
            });
            return;
          } else {
            // Update local state with the saved values
            _selectedStatusText = statusText;
            // _selectedStatusColor is already updated in _pickStatusColor
          }
        }
      }

      // Update avatar if changed
      if (_selectedAvatarUrl != _profile!.avatarUrl) {
        if (_selectedAvatarUrl != null && _selectedAvatarUrl!.isNotEmpty && !_selectedAvatarUrl!.startsWith('http')) {
          // Upload new avatar image via Bloc
          context.read<ProfileBloc>().add(UpdateProfileAvatarEvent(_selectedAvatarUrl!));
        } else if (_selectedAvatarUrl == null && _profile!.avatarUrl != null) {
          // Delete avatar via Bloc
          context.read<ProfileBloc>().add(DeleteProfileAvatarEvent());
        }
      }

      // Update banner if changed
      if (_selectedBannerUrl != _profile!.bannerUrl) {
        if (_selectedBannerUrl != null && _selectedBannerUrl!.isNotEmpty && !_selectedBannerUrl!.startsWith('http')) {
          // Upload new banner image via Bloc
          context.read<ProfileBloc>().add(UpdateProfileBannerEvent(_selectedBannerUrl!));
        } else if (_selectedBannerUrl == null && _profile!.bannerUrl != null) {
          // Delete banner via Bloc
          context.read<ProfileBloc>().add(DeleteProfileBannerEvent());
        }
      }

      // Update profile color if changed
      if (_selectedProfileColor != _profile!.profileColor) {
        final colorUpdated = await _updateProfileColor(_selectedProfileColor!);
        if (!colorUpdated) {
          setState(() {
            _savingState = SavingState.idle;
          });
          return;
        }
      }

      // Update profile background if changed
      if (_selectedProfileBackgroundUrl != _profile!.profileBackgroundUrl) {
        if (_selectedProfileBackgroundUrl != null && _selectedProfileBackgroundUrl!.isNotEmpty && !_selectedProfileBackgroundUrl!.startsWith('http')) {
          // Upload new profile background image
          final uploadedUrl = await _uploadProfileBackground(_selectedProfileBackgroundUrl!);
          if (uploadedUrl != null) {
            _selectedProfileBackgroundUrl = uploadedUrl;
          }
        } else if (_selectedProfileBackgroundUrl == null && _profile!.profileBackgroundUrl != null) {
          // Delete profile background via API (if endpoint exists)
          // For now, just set to null - deletion might need separate API call
          _selectedProfileBackgroundUrl = null;
        }
      }

      // Wait for all updates to be processed
      if (updatesToPerform.isNotEmpty) {
        await Future.wait(updatesToPerform);
        // Additional delay to ensure all Bloc events are processed
        await Future.delayed(const Duration(milliseconds: 300));
      }

      // All updates successful - update theme if color was changed, then show success animation
      if (_selectedProfileColor != _profile!.profileColor) {
        if (mounted) {
          context.read<ThemeBloc>().add(UpdateAccentColorEvent(_selectedProfileColor));
        }
      }

      // Refresh global profile data before showing success
      if (mounted) {
        context.read<ProfileBloc>().add(RefreshProfileEvent(forceRefresh: true));
      }

      setState(() {
        _savingState = SavingState.success;
      });

      // Wait for success animation and then close
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _savingState = SavingState.error;
      });

      // Auto-reset to idle after error animation
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() {
          _savingState = SavingState.idle;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ProfileBloc, ProfileState>(
          listener: (context, state) {
            // Handle avatar/banner updates if needed
            if (state is ProfileError) {
              setState(() {
                _savingState = SavingState.idle;
              });
            }
          },
        ),
        BlocListener<ThemeBloc, ThemeState>(
          listener: (context, state) {
            // Theme updated - UI will rebuild automatically
          },
        ),
      ],
      child: Stack(
        fit: StackFit.expand,
        children: [
          // AppBackground as bottom layer
          AppBackground(fallbackColor: Theme.of(context).colorScheme.surface),

          // Main content
          Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Content
                SafeArea(
                  bottom: true,
                  child: GestureDetector(
                    onTap: () {
                      FocusScope.of(context).unfocus();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) => Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideUpAnimation.value),
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 72, 16, 16), // Top padding for header
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AvatarEditSection(
                                  selectedAvatarUrl: _selectedAvatarUrl,
                                  onPickAvatar: _pickAvatar,
                                  onDeleteAvatar: _deleteAvatar,
                                ),
                                const SizedBox(height: 16),
                                CoverEditSection(
                                  selectedBannerUrl: _selectedBannerUrl,
                                  onPickCover: _pickCover,
                                  onDeleteCover: _deleteCover,
                                ),
                                const SizedBox(height: 16),
                                NameEditSection(
                                  controller: _nameController,
                                ),
                                const SizedBox(height: 16),
                                UsernameEditSection(
                                  controller: _usernameController,
                                ),
                                const SizedBox(height: 16),
                                DescriptionEditSection(
                                  controller: _descriptionController,
                                ),
                                const SizedBox(height: 16),
                                StatusEditSection(
                                  controller: _statusController,
                                  statusColor: _selectedStatusColor,
                                  onPickStatusColor: _pickStatusColor,
                                  subscription: _profile?.subscription,
                                ),
                                const SizedBox(height: 16),
                                AccentColorEditSection(
                                  selectedProfileColor: _selectedProfileColor,
                                  onPickAccentColor: _pickAccentColor,
                                ),
                                const SizedBox(height: 16),
                                ProfileBackgroundEditSection(
                                  selectedProfileBackgroundUrl: _selectedProfileBackgroundUrl,
                                  onPickProfileBackground: _pickProfileBackground,
                                  onDeleteProfileBackground: _deleteProfileBackground,
                                  subscription: _profile?.subscription,
                                ),
                                const SizedBox(height: 80), // Bottom padding for mini player
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Header positioned above content (like in main_tabs.dart)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) => Opacity(
                        opacity: _fadeAnimation.value,
                        child: Transform.translate(
                          offset: Offset(0, _slideUpAnimation.value),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
                            child: Row(
                              children: [
                                ValueListenableBuilder<String?>(
                                  valueListenable: StorageService.appBackgroundPathNotifier,
                                  builder: (context, backgroundPath, child) {
                                    final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
                                    final cardColor = hasBackground
                                        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                                        : Theme.of(context).colorScheme.surfaceContainerLow;

                                    return Card(
                                      margin: EdgeInsets.zero,
                                      color: cardColor,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () => Navigator.of(context).pop(),
                                              icon: Icon(
                                                Icons.arrow_back,
                                                color: Theme.of(context).colorScheme.onSurface,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Редактирование',
                                              style: AppTextStyles.postAuthor.copyWith(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const Spacer(),
                                ValueListenableBuilder<String?>(
                                  valueListenable: StorageService.appBackgroundPathNotifier,
                                  builder: (context, backgroundPath, child) {
                                    final hasBackground = backgroundPath != null && backgroundPath.isNotEmpty;
                                    final cardColor = hasBackground
                                        ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.7)
                                        : Theme.of(context).colorScheme.surfaceContainerLow;

                                    return Card(
                                      margin: EdgeInsets.zero,
                                      color: cardColor,
                                      child: Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: BlocBuilder<ThemeBloc, ThemeState>(
                                          builder: (context, state) {
                                            return IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: _hasUnsavedChanges && _savingState == SavingState.idle ? _saveProfile : null,
                                              icon: _savingState != SavingState.idle
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : Icon(
                                                      Icons.check,
                                                      color: _hasUnsavedChanges
                                                          ? Theme.of(context).colorScheme.primary
                                                          : Theme.of(context).colorScheme.onSurfaceVariant,
                                                      size: 22,
                                                    ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Saving overlay
          if (_savingState != SavingState.idle)
            SavingOverlay(
              state: _savingState == SavingState.saving
                  ? SavingOverlayState.saving
                  : _savingState == SavingState.success
                      ? SavingOverlayState.success
                      : SavingOverlayState.error,
            ),
        ],
      ),
    );
  }

  void _pickAvatar() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => MediaPickerModal(
        photoOnly: true,
        singleSelection: true,
        onMediaSelected: (imagePaths, videoPath, videoThumbnailPath, tracks) {
          if (imagePaths.isNotEmpty) {
            setState(() {
              _selectedAvatarUrl = imagePaths.first;
              _changedFields.add('avatar');
            });
          }
        },
      ),
    );
  }

  void _pickCover() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => MediaPickerModal(
        photoOnly: true,
        singleSelection: true,
        onMediaSelected: (imagePaths, videoPath, videoThumbnailPath, tracks) {
          if (imagePaths.isNotEmpty) {
            setState(() {
              _selectedBannerUrl = imagePaths.first;
              _changedFields.add('banner');
            });
          }
        },
      ),
    );
  }

  void _pickAccentColor() async {
    // Parse current color or use default
    Color initialColor = Theme.of(context).colorScheme.primary;
    if (_selectedProfileColor != null && _selectedProfileColor!.isNotEmpty) {
      try {
        final colorStr = _selectedProfileColor!.startsWith('#')
            ? _selectedProfileColor!.substring(1)
            : _selectedProfileColor!;
        final colorInt = int.parse(colorStr, radix: 16);
        if (colorStr.length == 6) {
          initialColor = Color(colorInt | 0xFF000000);
        }
      } catch (e) {
        // Keep default color
      }
    }

    final selectedColor = await color_picker.showColorPickerDialog(
      context,
      initialColor: initialColor,
      title: 'Акцентный цвет профиля',
    );

    if (selectedColor != null) {
      final colorHex = '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

      // Update local state
      setState(() {
        _selectedProfileColor = colorHex;
        _changedFields.add('profile_color');
      });
    }
  }

  void _pickStatusColor() async {
    // Parse current color or use default
    Color initialColor = const Color(0xFFFFFFFF); // White
    if (_selectedStatusColor != null && _selectedStatusColor!.isNotEmpty) {
      try {
        final colorStr = _selectedStatusColor!.startsWith('#')
            ? _selectedStatusColor!.substring(1)
            : _selectedStatusColor!;
        final colorInt = int.parse(colorStr, radix: 16);
        if (colorStr.length == 6) {
          initialColor = Color(colorInt | 0xFF000000);
        }
      } catch (e) {
        // Keep default color
      }
    }

    final selectedColor = await color_picker.showColorPickerDialog(
      context,
      initialColor: initialColor,
      title: 'Цвет статуса',
    );

    if (selectedColor != null) {
      setState(() {
        _selectedStatusColor = '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
        _changedFields.add('status');
      });
    }
  }

  void _pickProfileBackground() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => MediaPickerModal(
        photoOnly: true,
        singleSelection: true,
        onMediaSelected: (imagePaths, videoPath, videoThumbnailPath, tracks) {
          if (imagePaths.isNotEmpty) {
            setState(() {
              _selectedProfileBackgroundUrl = imagePaths.first;
              _changedFields.add('profile_background');
            });
          }
        },
      ),
    );
  }

  void _deleteAvatar() {
    setState(() {
      _selectedAvatarUrl = null;
      _changedFields.add('avatar');
    });
  }

  void _deleteCover() {
    setState(() {
      _selectedBannerUrl = null;
      _changedFields.add('banner');
    });
  }

  void _deleteProfileBackground() {
    setState(() {
      _selectedProfileBackgroundUrl = null;
      _changedFields.add('profile_background');
    });
  }

  Future<String?> _uploadProfileBackground(String imagePath) async {
    try {
      final file = await MultipartFile.fromFile(imagePath, filename: 'background.jpg');
      final formData = FormData.fromMap({'background': file});

      final response = await DioClient().postFormData('/api/profile/background', formData);

      if (response.statusCode == 200 && response.data['success'] == true) {
        return response.data['profile_background_url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _updateName(String name) async {
    try {
      final headers = await DioClient().getAuthHeaders();
      final response = await DioClient().post('/api/profile/update-name', {'name': name}, headers: headers);

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _updateUsername(String username) async {
    try {
      final headers = await DioClient().getAuthHeaders();
      final response = await DioClient().post('/api/profile/update-username', {'username': username}, headers: headers);

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _updateAbout(String about) async {
    try {
      final headers = await DioClient().getAuthHeaders();
      final response = await DioClient().post('/api/profile/update-about', {'about': about}, headers: headers);

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _updateStatus(String statusText, String statusColor) async {
    try {
      final headers = await DioClient().getAuthHeaders();
      // Ensure status color has # prefix for API
      final formattedStatusColor = statusColor.startsWith('#') ? statusColor : '#$statusColor';
      final response = await DioClient().post('/api/profile/v2update-profilestatus', {
        'status_text': statusText,
        'status_color': formattedStatusColor,
        'is_channel': false,
      }, headers: headers);

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _updateProfileColor(String profileColor) async {
    try {
      final headers = await DioClient().getAuthHeaders();
      final response = await DioClient().post('/api/user/settings/profile-color', {
        'profile_color': profileColor,
      }, headers: headers);

      if (response.statusCode == 200 && response.data['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
