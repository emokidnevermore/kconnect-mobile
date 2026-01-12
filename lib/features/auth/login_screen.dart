/// Экран входа в систему
///
/// Основной экран аутентификации для входа существующих пользователей.
/// Поддерживает вход по email или username с последующей навигацией к главному экрану.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kconnect_mobile/core/utils/theme_extensions.dart';
import 'package:kconnect_mobile/theme/app_gradients.dart';
import 'package:kconnect_mobile/theme/app_text_styles.dart';
import 'package:kconnect_mobile/routes/route_names.dart';
import 'package:kconnect_mobile/routes/app_router.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_bloc.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_event.dart';
import 'package:kconnect_mobile/features/auth/presentation/blocs/auth_state.dart';

/// Экран для входа пользователя в систему
///
/// Предоставляет форму для ввода учетных данных и осуществляет
/// переход к главному экрану приложения после успешной аутентификации.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _doLogin() {
    final login = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    if (login.isEmpty || pass.isEmpty) {
      _showError('Введите email/username и пароль');
      return;
    }

    context.read<AuthBloc>().add(LoginEvent(login, pass));
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Ошибка',
          style: AppTextStyles.body,
        ),
        content: Text(
          message,
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'ОК',
              style: AppTextStyles.button,
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          AppRouter.navigatorKey.currentState?.pushReplacementNamed(RouteNames.mainTabs);
        } else if (state is AuthError) {
          _showError(state.message);
        }
      },
      builder: (context, state) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          behavior: HitTestBehavior.opaque,
          child: Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                AppGradients.primary(context).createShader(bounds),
                            child: Text(
                              'K-Connect',
                              style: AppTextStyles.h1.copyWith(
                                fontSize: 36,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          TextField(
                            controller: _emailCtrl,
                            style: AppTextStyles.bodyMedium,
                            decoration: const InputDecoration(
                              hintText: 'Email или username',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _passCtrl,
                            obscureText: true,
                            style: AppTextStyles.bodyMedium,
                            decoration: const InputDecoration(
                              hintText: 'Пароль',
                            ),
                          ),
                          const SizedBox(height: 32),
                          state is AuthLoading
                              ? const CircularProgressIndicator()
                              : FilledButton(
                                  onPressed: _doLogin,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 32),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text('Войти', style: AppTextStyles.button),
                                ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(context, RouteNames.register),
                            child: Text(
                              'Нет аккаунта? Зарегистрируйся',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: context.dynamicPrimaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          ),
        );
      },
    );
  }
}
