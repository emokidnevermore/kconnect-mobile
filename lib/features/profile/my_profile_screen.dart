/// Экран моего профиля с поддержкой keep alive и кэширования
///
/// Отображает профиль текущего пользователя с постами,
/// статистикой и возможностью редактирования.
/// Поддерживает автоматическое обновление кэша при возобновлении работы приложения.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_bloc.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_event.dart';
import 'package:kconnect_mobile/features/profile/presentation/blocs/profile_state.dart';

import 'components/profile_background.dart';
import 'components/profile_content_card.dart';
import 'components/profile_posts_section.dart';
import 'utils/profile_color_utils.dart';
import '../../core/widgets/profile_accent_color_provider.dart';
import 'widgets/profile_edit_screen.dart';

/// Экран моего профиля с поддержкой keep alive
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        if (state is ProfileInitial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<ProfileBloc>().add(LoadCurrentProfileEvent());
          });
        }

        ProfileLoaded? profileState;

        if (state.isLoaded) {
          profileState = state.asLoaded!;
        }

        if (profileState != null) {
          return _buildProfileView(profileState);
        }

        if (state.isError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.asError!.message,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    if (!mounted) return;
                    context.read<ProfileBloc>().add(LoadCurrentProfileEvent());
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        if (state.isUpdated) {
          final updatedState = state.asUpdated!;
          profileState = ProfileLoaded(
            profile: updatedState.profile,
            isOwnProfile: true,
            isSkeleton: false,
          );
          return _buildProfileView(profileState);
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildProfileView(ProfileLoaded profileState) {
    final profile = profileState.profile;
    final accentColor = ProfileColorUtils.getProfileAccentColor(profile, context);
    final profileColorScheme = ProfileColorUtils.createProfileColorScheme(accentColor);

    final scrollView = ProfileAccentColorProvider(
      accentColor: accentColor,
      child: RefreshIndicator(
        onRefresh: () async {
          context.read<ProfileBloc>().add(RefreshProfileEvent());
        },
        color: accentColor,
        child: CustomScrollView(
          slivers: [
            // Отступ сверху под хедер
            const SliverToBoxAdapter(
              child: SizedBox(height: 48),
            ),
            SliverToBoxAdapter(
              child: ProfileContentCard(
                profile: profile,
                followingInfo: profileState.followingInfo,
                profileState: profileState,
                accentColor: accentColor,
                onEditPressed: _showEditProfileDialog,
                onFollowPressed: () => context.read<ProfileBloc>().add(FollowUserEvent(profile.username)),
                onUnfollowPressed: () => context.read<ProfileBloc>().add(UnfollowUserEvent(profile.username)),
                hasProfileBackground: profile.profileBackgroundUrl != null && profile.profileBackgroundUrl!.isNotEmpty,
                profileColorScheme: profileColorScheme,
              ),
            ),
            ProfilePostsSection(
              profileState: profileState,
              accentColor: accentColor,
              hasProfileBackground: profile.profileBackgroundUrl != null && profile.profileBackgroundUrl!.isNotEmpty,
              profileColorScheme: profileColorScheme,
            ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );

    final screenWidget = Container(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: ProfileBackground(
              backgroundUrl: profile.profileBackgroundUrl,
              profileColorScheme: profileColorScheme,
            ),
          ),
          SafeArea(
            bottom: true,
            child: scrollView,
          ),
        ],
      ),
    );

    return screenWidget;
  }

  VoidCallback get _showEditProfileDialog => () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ProfileEditScreen(),
          ),
        );
      };
}
