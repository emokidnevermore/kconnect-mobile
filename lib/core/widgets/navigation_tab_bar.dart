/// Таб-бар для навигационной панели
///
/// Компонент таб-бара с поддержкой бейджей и адаптивных размеров
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../features/messages/presentation/blocs/messages_bloc.dart';
import '../../features/messages/presentation/blocs/messages_state.dart';
import 'glass_mode_wrapper.dart';

/// Таб-бар навигации
class NavigationTabBar extends StatelessWidget {
  /// Ширина таб-бара
  final double width;

  /// Высота таб-бара
  final double height;

  /// Колбэк при нажатии на таб
  final Function(int) onTabTapped;

  /// Текущий индекс таба
  final int currentIndex;

  const NavigationTabBar({
    super.key,
    required this.width,
    required this.height,
    required this.onTabTapped,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return GlassModeWrapper(
      borderRadius: 25,
      settings: const LiquidGlassSettings(
        thickness: 15,
        glassColor: Color(0x33FFFFFF),
        lightIntensity: 1.5,
        chromaticAberration: 1,
        saturation: 1.1,
        ambientStrength: 1,
        blur: 4,
        refractiveIndex: 1.8,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Row(
          children: [
            Expanded(child: _buildTabIcon(0, Icons.person, currentIndex)),
            Expanded(child: _buildTabIcon(1, Icons.music_note, currentIndex)),
            Expanded(child: _buildTabIcon(2, Icons.newspaper, currentIndex)),
            Expanded(child: _buildMessagesTabIcon(currentIndex)),
            Expanded(child: _buildTabIcon(4, Icons.grid_view, currentIndex)),
          ],
        ),
      ),
    );
  }

  /// Построить иконку таба
  Widget _buildTabIcon(int index, IconData icon, int currentIndex) {
    final isSelected = currentIndex == index;

    return Builder(
      builder: (context) => IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        onPressed: () => onTabTapped(index),
        icon: Icon(
          icon,
          size: 24,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Построить иконку таба сообщений с бейджем
  Widget _buildMessagesTabIcon(int currentIndex) {
    final isSelected = currentIndex == 3;

    return BlocSelector<MessagesBloc, MessagesState, int>(
      selector: (state) => state.totalUnreadCount,
      builder: (context, unreadCount) {
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => onTabTapped(3),
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text(
              unreadCount > 99 ? '99+' : unreadCount.toString(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            textColor: Theme.of(context).colorScheme.onPrimary,
            alignment: AlignmentDirectional.topEnd,
            offset: const Offset(4, -4),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 24,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
