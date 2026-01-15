import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_state.dart';
import 'package:kconnect_mobile/features/feed/domain/models/post.dart';
import 'package:kconnect_mobile/features/feed/domain/usecases/fetch_posts_usecase.dart';
import 'package:kconnect_mobile/features/profile/domain/models/following_info.dart';
import 'package:kconnect_mobile/features/profile/domain/models/profile_posts_response.dart';
import 'package:kconnect_mobile/features/profile/domain/models/user_profile.dart';
import 'package:kconnect_mobile/features/profile/domain/repositories/profile_repository.dart';
import 'package:kconnect_mobile/features/profile/domain/usecases/fetch_pinned_post_usecase.dart';
import 'package:kconnect_mobile/features/profile/domain/usecases/fetch_user_posts_usecase.dart';
import 'package:kconnect_mobile/features/profile/domain/usecases/fetch_user_profile_usecase.dart';
import 'package:kconnect_mobile/features/profile/domain/usecases/follow_user_usecase.dart';
import 'package:kconnect_mobile/features/profile/domain/usecases/update_profile_usecase.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_event.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_state.dart';

/// Refactored ProfileBloc with simplified state management
///
/// Key improvements:
/// - Simplified loading logic with clear states
/// - Pull to refresh always loads fresh data
/// - Concurrent data loading instead of sequential
/// - Better error handling and state transitions
/// - Proper reload after profile editing
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final FetchUserProfileUseCase _fetchProfileUseCase;
  final FetchUserPostsUseCase _fetchUserPostsUseCase;
  final FetchPinnedPostUseCase _fetchPinnedPostUseCase;
  final UpdateProfileUseCase _updateProfileUseCase;
  final FollowUserUseCase _followUserUseCase;
  final LikePostUseCase _likePostUseCase;
  final ProfileRepository _repository;
  final AuthBloc _authBloc;

  /// Simple loading state tracking - just one flag per operation type
  bool _isLoadingProfile = false;
  bool _isLoadingPosts = false;

  ProfileBloc({
    required AuthBloc authBloc,
    required FetchUserProfileUseCase fetchProfileUseCase,
    required FetchUserPostsUseCase fetchUserPostsUseCase,
    required FetchPinnedPostUseCase fetchPinnedPostUseCase,
    required UpdateProfileUseCase updateProfileUseCase,
    required FollowUserUseCase followUserUseCase,
    required LikePostUseCase likePostUseCase,
    required ProfileRepository repository,
  })  : _authBloc = authBloc,
        _fetchProfileUseCase = fetchProfileUseCase,
        _fetchUserPostsUseCase = fetchUserPostsUseCase,
        _fetchPinnedPostUseCase = fetchPinnedPostUseCase,
        _updateProfileUseCase = updateProfileUseCase,
        _followUserUseCase = followUserUseCase,
        _likePostUseCase = likePostUseCase,
        _repository = repository,
        super(ProfileInitial()) {
    on<LoadProfileEvent>(_onLoadProfile);
    on<LoadCurrentProfileEvent>(_onLoadCurrentProfile);
    on<LoadProfileStatsEvent>(_onLoadProfileStats);
    on<LoadProfilePostsEvent>(_onLoadProfilePosts);
    on<FetchMoreProfilePostsEvent>(_onFetchMoreProfilePosts);
    on<LoadFollowingInfoEvent>(_onLoadFollowingInfo);
    on<LoadFollowingInfoWithFollowersEvent>(_onLoadFollowingInfoWithFollowers);
    on<LikeProfilePostEvent>(_onLikeProfilePost);
    on<UpdateProfileEvent>(_onUpdateProfile);
    on<UpdateProfileStatusEvent>(_onUpdateProfileStatus);
    on<UpdateProfileAvatarEvent>(_onUpdateProfileAvatar);
    on<UpdateProfileBannerEvent>(_onUpdateProfileBanner);
    on<DeleteProfileAvatarEvent>(_onDeleteProfileAvatar);
    on<DeleteProfileBannerEvent>(_onDeleteProfileBanner);
    on<AddSocialLinkEvent>(_onAddSocialLink);
    on<DeleteSocialLinkEvent>(_onDeleteSocialLink);
    on<FollowUserEvent>(_onFollowUser);
    on<UnfollowUserEvent>(_onUnfollowUser);
    on<ToggleNotificationsEvent>(_onToggleNotifications);
    on<RefreshProfileEvent>(_onRefreshProfile);
    on<ClearProfileCacheEvent>(_onClearProfileCache);
    on<PushProfileStackEvent>(_onPushProfileStack);
    on<PopProfileStackEvent>(_onPopProfileStack);
    on<RetryProfilePostsEvent>(_onRetryProfilePosts);
  }

  String? get _currentUserId {
    if (_authBloc.state is AuthAuthenticated) {
      return (_authBloc.state as AuthAuthenticated).user.username;
    }
    return null;
  }

  String? get _currentUserDBId {
    if (_authBloc.state is AuthAuthenticated) {
      return (_authBloc.state as AuthAuthenticated).user.id;
    }
    return null;
  }

  bool _isOwnProfile(String userIdentifier) {
    return userIdentifier == 'current' || userIdentifier == _currentUserId;
  }

  /// Load profile data for other users
  Future<void> _loadOtherProfileData(String userIdentifier, bool forceRefresh, Emitter<ProfileState> emit, {bool isRefreshing = false}) async {
    if (_isLoadingProfile) {
      debugPrint('ProfileBloc: Already loading profile, skipping');
      return;
    }

    _isLoadingProfile = true;

    try {
      // Always emit loading state for fresh loads (not for refresh overlay)
      if (!isRefreshing) {
        emit(ProfileLoading());
      }

      // Load profile data using use case
      final profile = await _fetchProfileUseCase.execute(
        userIdentifier,
        forceRefresh: forceRefresh,
      );

      // Load posts and pinned post concurrently
      final postsFuture = _repository.fetchUserPosts(
        userId: profile.id.toString(),
        page: 1,
        perPage: 10,
        forceRefresh: forceRefresh,
      );

      final pinnedPostFuture = _fetchPinnedPostUseCase.execute(profile.username);

      final [postsResponse, pinnedPost] = await Future.wait([
        postsFuture,
        pinnedPostFuture,
      ]);

      final ProfilePostsResponse posts = postsResponse as ProfilePostsResponse;
      final Post? pinned = pinnedPost as Post?;

      // Filter out pinned post from regular posts
      final filteredPosts = pinned != null
          ? posts.posts.where((post) => post.id != pinned.id).toList()
          : posts.posts;

      // Load following info
      FollowingInfo? followingInfo;
      if (_currentUserDBId != null) {
        try {
          followingInfo = await _repository.fetchFollowingInfoWithFollowers(
            profileId: profile.id.toString(),
            currentUserId: _currentUserDBId!,
          );
        } catch (e) {
          debugPrint('ProfileBloc: Failed to load following info: $e');
          // Continue without following info - it's optional
        }
      }

      // Emit loaded state with complete data
      final loadedState = ProfileLoaded(
        profile: profile,
        isOwnProfile: false,
        posts: filteredPosts,
        hasNextPosts: posts.hasNext,
        currentPostsPage: posts.page,
        postsPerPage: posts.perPage,
        pinnedPost: pinned,
        followingInfo: followingInfo,
        isRefreshing: false,
        postsError: false,
        isLoadingPosts: false,
      );

      emit(loadedState);

      debugPrint('ProfileBloc: Successfully loaded other profile ${profile.username} with ${filteredPosts.length} posts');

    } catch (e) {
      debugPrint('ProfileBloc: Error loading other profile: $e');

      // Emit error state
      if (!isRefreshing) {
        emit(ProfileError('Не удалось загрузить профиль: ${e.toString()}'));
      } else {
        // For refresh failures, emit error but keep existing data if available
        final currentState = state;
        if (currentState is ProfileLoaded) {
          emit(currentState.copyWith(
            isRefreshing: false,
            postsError: true,
            postsErrorMessage: 'Не удалось обновить данные: ${e.toString()}',
          ));
        } else {
          emit(ProfileError('Не удалось загрузить профиль: ${e.toString()}'));
        }
      }
    } finally {
      _isLoadingProfile = false;
    }
  }

  /// Load profile data for current user (own profile) - uses different loading logic
  Future<void> _loadCurrentProfileData(bool forceRefresh, Emitter<ProfileState> emit, {bool isRefreshing = false}) async {
    if (_isLoadingProfile) {
      debugPrint('ProfileBloc: Already loading current profile, skipping');
      return;
    }

    _isLoadingProfile = true;

    try {
      // Always emit loading state for fresh loads (not for refresh overlay)
      if (!isRefreshing) {
        emit(ProfileLoading());
      }

      // Load current profile data using direct repository call (includes all profile fields)
      final profile = await _repository.fetchCurrentUserProfile(
        forceRefresh: forceRefresh,
      );

      // Load stats
      final stats = await _repository.fetchUserStats(profile.username);

      // Load posts and pinned post concurrently
      final postsFuture = _repository.fetchUserPosts(
        userId: profile.id.toString(),
        page: 1,
        perPage: 10,
        forceRefresh: forceRefresh,
      );

      final pinnedPostFuture = _fetchPinnedPostUseCase.execute(profile.username);

      final [postsResponse, pinnedPost] = await Future.wait([
        postsFuture,
        pinnedPostFuture,
      ]);

      final ProfilePostsResponse posts = postsResponse as ProfilePostsResponse;
      final Post? pinned = pinnedPost as Post?;

      // Filter out pinned post from regular posts
      final filteredPosts = pinned != null
          ? posts.posts.where((post) => post.id != pinned.id).toList()
          : posts.posts;

      // Emit loaded state with complete data for own profile
      final loadedState = ProfileLoaded(
        profile: profile,
        isOwnProfile: true,
        stats: stats,
        posts: filteredPosts,
        hasNextPosts: posts.hasNext,
        currentPostsPage: posts.page,
        postsPerPage: posts.perPage,
        pinnedPost: pinned,
        followingInfo: null, // Own profile doesn't need following info
        isRefreshing: false,
        postsError: false,
        isLoadingPosts: false,
      );

      debugPrint('ProfileBloc: Emitting loaded state for current profile ${profile.username}, name: ${profile.name}, isRefreshing: false');
      emit(loadedState);

      debugPrint('ProfileBloc: Successfully loaded current profile ${profile.username} with ${filteredPosts.length} posts');

    } catch (e) {
      debugPrint('ProfileBloc: Error loading current profile: $e');

      // Emit error state
      if (!isRefreshing) {
        emit(ProfileError('Не удалось загрузить профиль: ${e.toString()}'));
      } else {
        // For refresh failures, emit error but keep existing data if available
        final currentState = state;
        if (currentState is ProfileLoaded) {
          emit(currentState.copyWith(
            isRefreshing: false,
            postsError: true,
            postsErrorMessage: 'Не удалось обновить данные: ${e.toString()}',
          ));
        } else {
          emit(ProfileError('Не удалось загрузить профиль: ${e.toString()}'));
        }
      }
    } finally {
      _isLoadingProfile = false;
    }
  }

  void _onLoadProfile(LoadProfileEvent event, Emitter<ProfileState> emit) async {
    debugPrint('ProfileBloc: _onLoadProfile called for ${event.userIdentifier}');
    if (_isOwnProfile(event.userIdentifier)) {
      await _loadCurrentProfileData(event.forceRefresh, emit);
    } else {
      await _loadOtherProfileData(event.userIdentifier, event.forceRefresh, emit);
    }
  }

  void _onLoadCurrentProfile(LoadCurrentProfileEvent event, Emitter<ProfileState> emit) async {
    debugPrint('ProfileBloc: _onLoadCurrentProfile called');
    await _loadCurrentProfileData(event.forceRefresh, emit);
  }

  /// Simplified refresh - always loads fresh data
  void _onRefreshProfile(RefreshProfileEvent event, Emitter<ProfileState> emit) async {
    debugPrint('ProfileBloc: _onRefreshProfile called');

    final currentState = state;
    if (currentState is ProfileLoaded) {
      debugPrint('ProfileBloc: Starting refresh for profile ${currentState.profile.username}, current name: ${currentState.profile.name}');

      // Clear cache first to ensure fresh data
      if (currentState.isOwnProfile) {
        await _repository.clearUserCache('current');
        debugPrint('ProfileBloc: Cleared current user cache');
      } else {
        await _repository.clearUserCache(currentState.profile.username);
        debugPrint('ProfileBloc: Cleared user cache for ${currentState.profile.username}');
      }

      // Start refresh - show loading overlay but keep existing data visible
      final refreshingState = currentState.copyWith(isRefreshing: true);
      emit(refreshingState);
      debugPrint('ProfileBloc: Emitted refreshing state');

      try {
        if (currentState.isOwnProfile) {
          await _loadCurrentProfileData(true, emit, isRefreshing: true);
        } else {
          await _loadOtherProfileData(currentState.profile.username, true, emit, isRefreshing: true);
        }
      } catch (e) {
        debugPrint('ProfileBloc: Error during refresh: $e');
        // On error, emit state with isRefreshing=false to hide loading overlay
        if (state is ProfileLoaded) {
          emit((state as ProfileLoaded).copyWith(isRefreshing: false));
        }
        rethrow;
      }
    } else {
      // No current profile loaded, do full load
      debugPrint('ProfileBloc: No current profile loaded, doing full load');
      add(LoadCurrentProfileEvent(forceRefresh: true));
    }
  }

  void _onLoadProfileStats(LoadProfileStatsEvent event, Emitter<ProfileState> emit) async {
    try {
      final stats = await _repository.fetchUserStats(event.userIdentifier);
      emit(ProfileStatsLoaded(stats));
    } catch (e) {
      emit(ProfileError('Не удалось загрузить статистику: ${e.toString()}'));
    }
  }

  void _onUpdateProfile(UpdateProfileEvent event, Emitter<ProfileState> emit) async {
    try {
      final currentState = state;
      if (currentState is ProfileLoaded) {
        emit(ProfileUpdating(currentState.profile));

        await _updateProfileUseCase.updateName(event.name);
        await _updateProfileUseCase.updateUsername(event.username);
        await _updateProfileUseCase.updateAbout(event.about);

        // After update, trigger complete reload of profile data
        await _loadCurrentProfileData(true, emit);
      }
    } catch (e) {
      emit(ProfileError('Не удалось обновить профиль: ${e.toString()}'));
    }
  }

  void _onUpdateProfileStatus(UpdateProfileStatusEvent event, Emitter<ProfileState> emit) async {
    try {
      final currentState = state;
      if (currentState is ProfileLoaded && currentState.isOwnProfile) {
        await _updateProfileUseCase.updateStatus(event.statusText, event.statusColor);

        // Trigger complete reload after status update
        add(RefreshProfileEvent(forceRefresh: true));
      }
    } catch (e) {
      emit(ProfileError('Не удалось обновить статус: ${e.toString()}'));
    }
  }

  void _onUpdateProfileAvatar(UpdateProfileAvatarEvent event, Emitter<ProfileState> emit) async {
    try {
      final currentState = state;
      if (currentState is ProfileLoaded && currentState.isOwnProfile) {
        await _updateProfileUseCase.updateAvatar(event.avatarPath);

        // Trigger complete reload after avatar update
        add(RefreshProfileEvent(forceRefresh: true));
      }
    } catch (e) {
      emit(ProfileError('Не удалось обновить аватар: ${e.toString()}'));
    }
  }

  void _onUpdateProfileBanner(UpdateProfileBannerEvent event, Emitter<ProfileState> emit) async {
    try {
      final currentState = state;
      if (currentState is ProfileLoaded && currentState.isOwnProfile) {
        await _updateProfileUseCase.updateBanner(event.bannerPath);

        // Trigger complete reload after banner update
        add(RefreshProfileEvent(forceRefresh: true));
      }
    } catch (e) {
      emit(ProfileError('Не удалось обновить баннер: ${e.toString()}'));
    }
  }

  void _onDeleteProfileAvatar(DeleteProfileAvatarEvent event, Emitter<ProfileState> emit) async {
    try {
      final currentState = state;
      if (currentState is ProfileLoaded && currentState.isOwnProfile) {
        await _updateProfileUseCase.deleteAvatar();

        // Trigger complete reload after avatar deletion
        add(RefreshProfileEvent(forceRefresh: true));
      }
    } catch (e) {
      emit(ProfileError('Не удалось удалить аватар: ${e.toString()}'));
    }
  }

  void _onDeleteProfileBanner(DeleteProfileBannerEvent event, Emitter<ProfileState> emit) async {
    try {
      final currentState = state;
      if (currentState is ProfileLoaded && currentState.isOwnProfile) {
        await _updateProfileUseCase.deleteBanner();

        // Trigger complete reload after banner deletion
        add(RefreshProfileEvent(forceRefresh: true));
      }
    } catch (e) {
      emit(ProfileError('Не удалось удалить баннер: ${e.toString()}'));
    }
  }

  void _onAddSocialLink(AddSocialLinkEvent event, Emitter<ProfileState> emit) async {
    try {
      final currentState = state;
      if (currentState is ProfileLoaded && currentState.isOwnProfile) {
        await _updateProfileUseCase.addSocialLink(event.name, event.link);

        // Trigger complete reload after social link addition
        add(RefreshProfileEvent(forceRefresh: true));
      }
    } catch (e) {
      emit(ProfileError('Не удалось добавить ссылку: ${e.toString()}'));
    }
  }

  void _onDeleteSocialLink(DeleteSocialLinkEvent event, Emitter<ProfileState> emit) async {
    try {
      final currentState = state;
      if (currentState is ProfileLoaded && currentState.isOwnProfile) {
        await _updateProfileUseCase.deleteSocialLink(event.name);

        // Trigger complete reload after social link deletion
        add(RefreshProfileEvent(forceRefresh: true));
      }
    } catch (e) {
      emit(ProfileError('Не удалось удалить ссылку: ${e.toString()}'));
    }
  }

  void _onFollowUser(FollowUserEvent event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is! ProfileLoaded || currentState.isOwnProfile) {
      return;
    }

    try {
      final response = await _followUserUseCase.follow(currentState.profile.id);

      // Update following info based on API response
      final updatedFollowingInfo = FollowingInfo(
        currentUserFollows: response['is_following'] ?? false,
        currentUserIsFriend: response['is_friend'] ?? false,
        followsBack: response['is_followed_by'] ?? false,
        isSelf: response['is_self'] ?? false,
      );

      final updatedState = currentState.copyWith(followingInfo: updatedFollowingInfo);
      emit(updatedState);
    } catch (e) {
      debugPrint('Failed to follow user: ${e.toString()}');
    }
  }

  void _onUnfollowUser(UnfollowUserEvent event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is! ProfileLoaded || currentState.isOwnProfile) {
      return;
    }

    try {
      final response = await _followUserUseCase.unfollow(currentState.profile.id);

      // Update following info based on API response
      final updatedFollowingInfo = FollowingInfo(
        currentUserFollows: response['is_following'] ?? false,
        currentUserIsFriend: response['is_friend'] ?? false,
        followsBack: response['is_followed_by'] ?? false,
        isSelf: response['is_self'] ?? false,
      );

      final updatedState = currentState.copyWith(followingInfo: updatedFollowingInfo);
      emit(updatedState);
    } catch (e) {
      debugPrint('Failed to unfollow user: ${e.toString()}');
    }
  }

  void _onToggleNotifications(ToggleNotificationsEvent event, Emitter<ProfileState> emit) async {
    try {
      await _followUserUseCase.toggleNotifications(
        event.followedUsername,
        event.enabled,
      );

      final message = event.enabled ? 'Уведомления включены' : 'Уведомления отключены';

      if (state is ProfileLoaded) {
        emit(ProfileUpdated((state as ProfileLoaded).profile, message));
      }
    } catch (e) {
      emit(ProfileError('Не удалось изменить настройки уведомлений: ${e.toString()}'));
    }
  }

  void _onClearProfileCache(ClearProfileCacheEvent event, Emitter<ProfileState> emit) async {
    try {
      await _repository.clearCache();
      emit(ProfileInitial());
    } catch (e) {
      emit(ProfileError('Не удалось очистить кеш: ${e.toString()}'));
    }
  }

  void _onLoadProfilePosts(LoadProfilePostsEvent event, Emitter<ProfileState> emit) async {
    debugPrint('ProfileBloc: _onLoadProfilePosts called');

    if (_isLoadingPosts) {
      debugPrint('ProfileBloc: Already loading posts, skipping');
      return;
    }

    _isLoadingPosts = true;

    try {
      final currentState = state;
      if (currentState is! ProfileLoaded) {
        debugPrint('ProfileBloc: Cannot load posts - not in loaded state');
        return;
      }

      emit(currentState.copyWith(isLoadingPosts: true, postsError: false, postsErrorMessage: null));

      // Load posts and pinned post concurrently
      final [postsResponse, pinnedPost] = await Future.wait([
        _repository.fetchUserPosts(
          userId: currentState.profile.id.toString(),
          page: 1,
          perPage: 10,
          forceRefresh: event.forceRefresh,
        ),
        _fetchPinnedPostUseCase.execute(currentState.profile.username),
      ]);

      final ProfilePostsResponse posts = postsResponse as ProfilePostsResponse;
      final Post? pinned = pinnedPost as Post?;

      // Filter out pinned post from regular posts
      final filteredPosts = pinned != null
          ? posts.posts.where((post) => post.id != pinned.id).toList()
          : posts.posts;

      final updatedState = currentState.copyWith(
        posts: filteredPosts,
        hasNextPosts: posts.hasNext,
        currentPostsPage: posts.page,
        pinnedPost: pinned,
        isLoadingPosts: false,
      );

      emit(updatedState);

    } catch (e) {
      debugPrint('ProfileBloc: Error loading posts: $e');
      final currentState = state;
      if (currentState is ProfileLoaded) {
        emit(currentState.copyWith(
          isLoadingPosts: false,
          postsError: true,
          postsErrorMessage: 'Не удалось загрузить посты: ${e.toString()}',
        ));
      }
    } finally {
      _isLoadingPosts = false;
    }
  }

  void _onFetchMoreProfilePosts(FetchMoreProfilePostsEvent event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is! ProfileLoaded || currentState.isLoadingPosts || !currentState.hasNextPosts) {
      return;
    }

    try {
      emit(currentState.copyWith(isLoadingPosts: true));

      final response = await _fetchUserPostsUseCase.execute(
        userId: event.userId,
        page: event.page,
        perPage: event.perPage,
      );

      // Filter out pinned post if it exists
      final ProfilePostsResponse posts = response;
      final filteredPosts = currentState.pinnedPost != null
          ? posts.posts.where((post) => post.id != currentState.pinnedPost!.id).toList()
          : posts.posts;

      emit(currentState.copyWith(
        isLoadingPosts: false,
      ).addPosts(ProfilePostsResponse(
        posts: filteredPosts,
        hasNext: posts.hasNext,
        hasPrev: posts.hasPrev,
        page: posts.page,
        pages: posts.pages,
        perPage: posts.perPage,
        total: posts.total,
      )));
    } catch (e) {
      final loadedState = state;
      if (loadedState is ProfileLoaded) {
        emit(loadedState.copyWith(isLoadingPosts: false));
      }
    }
  }

  void _onLoadFollowingInfo(LoadFollowingInfoEvent event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is! ProfileLoaded || currentState.isOwnProfile) {
      return;
    }

    try {
      final followingInfo = await _repository.fetchFollowingInfo(
        profileId: event.profileId,
        currentUserId: event.currentUserId,
      );

      emit(currentState.copyWith(followingInfo: followingInfo));
    } catch (e) {
      // Following info is optional, don't emit error
    }
  }

  void _onLoadFollowingInfoWithFollowers(LoadFollowingInfoWithFollowersEvent event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is! ProfileLoaded || currentState.isOwnProfile) {
      return;
    }

    try {
      final followingInfo = await _repository.fetchFollowingInfoWithFollowers(
        profileId: event.profileId,
        currentUserId: event.currentUserId,
      );

      emit(currentState.copyWith(followingInfo: followingInfo));
    } catch (e) {
      // Following info is optional, don't emit error
    }
  }

  Future<void> _onLikeProfilePost(LikeProfilePostEvent event, Emitter<ProfileState> emit) async {
    final currentState = state;
    if (currentState is! ProfileLoaded) return;

    // Prevent concurrent likes
    if (currentState.processingLikes.contains(event.postId)) {
      return;
    }

    final post = event.post;
    final processingLikes = {...currentState.processingLikes, event.postId};
    emit(currentState.copyWith(processingLikes: processingLikes));

    try {
      // Optimistic update
      final optimisticPost = post.copyWith(
        isLiked: !post.isLiked,
        likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
      );

      List<Post> optimisticPosts = currentState.posts.map((p) => p.id == event.postId ? optimisticPost : p).toList();
      Post? optimisticPinnedPost = currentState.pinnedPost?.id == event.postId ? optimisticPost : currentState.pinnedPost;

      emit(currentState.copyWith(
        posts: optimisticPosts,
        pinnedPost: optimisticPinnedPost,
      ));

      // API call
      final serverPost = await _likePostUseCase(event.postId);

      // Server response takes precedence
      final serverUpdatedPost = post.copyWith(
        isLiked: serverPost.isLiked,
        likesCount: serverPost.likesCount,
        dislikesCount: serverPost.dislikesCount,
      );

      final serverPosts = currentState.posts.map((p) => p.id == event.postId ? serverUpdatedPost : p).toList();
      final serverPinnedPost = currentState.pinnedPost?.id == event.postId ? serverUpdatedPost : currentState.pinnedPost;

      emit(currentState.copyWith(
        posts: serverPosts,
        pinnedPost: serverPinnedPost,
        processingLikes: currentState.processingLikes.where((id) => id != event.postId).toSet(),
      ));
    } catch (e) {
      // Revert on error
      final revertedPost = post.copyWith(
        isLiked: !post.isLiked,
        likesCount: post.isLiked ? post.likesCount - 1 : post.likesCount + 1,
      );

      final revertedPosts = currentState.posts.map((p) => p.id == event.postId ? revertedPost : p).toList();
      final revertedPinnedPost = currentState.pinnedPost?.id == event.postId ? revertedPost : currentState.pinnedPost;

      emit(currentState.copyWith(
        posts: revertedPosts,
        pinnedPost: revertedPinnedPost,
        processingLikes: currentState.processingLikes.where((id) => id != event.postId).toSet(),
      ));
    }
  }

  /// Simplified profile stack management - removed complex validation logic
  final List<ProfileStackEntry> _profileStack = [];

  void _onPushProfileStack(PushProfileStackEvent event, Emitter<ProfileState> emit) async {
    debugPrint('ProfileBloc: _onPushProfileStack called with username=${event.username}');

    // Check if already in stack
    final existingIndex = _profileStack.indexWhere((entry) => entry.username == event.username);
    if (existingIndex != -1) {
      final entry = _profileStack.removeAt(existingIndex);
      _profileStack.add(entry);
      emit(entry.state);
      return;
    }

    // Create loading state for new profile
    final skeletonState = ProfileLoaded(
      profile: createSkeletonProfile(event.username),
      isOwnProfile: false,
      isSkeleton: true,
    );

    _profileStack.add(ProfileStackEntry(username: event.username, state: skeletonState));
    emit(skeletonState);

    // Load the profile
    try {
      if (_isOwnProfile(event.username)) {
        await _loadCurrentProfileData(false, emit);
      } else {
        await _loadOtherProfileData(event.username, false, emit);
      }
    } catch (e) {
      debugPrint('ProfileBloc: Error loading profile in _onPushProfileStack: $e');
      final errorState = ProfileError('Не удалось загрузить профиль: ${e.toString()}');
      if (_profileStack.isNotEmpty && _profileStack.last.username == event.username) {
        _profileStack.last = ProfileStackEntry(username: event.username, state: errorState);
      }
      emit(errorState);
    }
  }

  void _onPopProfileStack(PopProfileStackEvent event, Emitter<ProfileState> emit) {
    if (_profileStack.isNotEmpty) {
      _profileStack.removeLast();
      if (_profileStack.isNotEmpty) {
        emit(_profileStack.last.state);
      } else {
        emit(ProfileInitial());
      }
    }
  }

  void _onRetryProfilePosts(RetryProfilePostsEvent event, Emitter<ProfileState> emit) {
    final currentState = state;
    if (currentState is ProfileLoaded && currentState.postsError) {
      emit(currentState.copyWith(postsError: false, postsErrorMessage: null, posts: []));
      add(LoadProfilePostsEvent(currentState.profile.id.toString(), forceRefresh: true));
    }
  }

  /// Helper to create skeleton profile
  UserProfile createSkeletonProfile(String username) {
    return UserProfile(
      id: 0,
      name: username,
      username: username,
      followersCount: 0,
      followingCount: 0,
      friendsCount: 0,
      postsCount: 0,
      photosCount: 0,
      profileColor: null,
      verificationStatus: 'none',
      scam: false,
      accountType: 'user',
      elementConnected: false,
      registrationDate: DateTime.now(),
      interests: const [],
      purchasedUsernames: const [],
      socials: const [],
      connectInfo: const [],
      equippedItems: const [],
    );
  }
}
