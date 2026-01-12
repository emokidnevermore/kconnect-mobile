import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Состояния BLoC для темы
///
/// Определяет все возможные состояния процесса управления темой,
/// включая состояния загрузки, успеха и ошибок.

/// Базовый класс для всех состояний темы
abstract class ThemeState extends Equatable {
  const ThemeState();

  @override
  List<Object> get props => [];
}

class ThemeInitial extends ThemeState {}

class ThemeLoaded extends ThemeState {
  final ColorScheme colorScheme;

  const ThemeLoaded(this.colorScheme);

  Color get primaryColor => colorScheme.primary;
  
  Color get accentColor => colorScheme.primary;

  @override
  List<Object> get props => [colorScheme];
}
