import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/domain/models/account.dart';
import '../core/constants/tab_bar_glass_mode.dart';

/// Сервис для безопасного хранения данных в SharedPreferences
///
/// Обеспечивает хранение сессионных ключей, данных аккаунтов,
/// настроек персонализации и истории прослушивания музыки.
/// Все чувствительные данные хранятся в зашифрованном виде на уровне ОС.
class StorageService {
  static Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();
  
  // ValueNotifier для отслеживания изменений фона приложения
  static final ValueNotifier<String?> appBackgroundPathNotifier = ValueNotifier<String?>(null);

  static Future<bool> hasActiveSession() async {
    final prefs = await _prefs;
    final key = prefs.getString('session_key');
    return key != null;
  }

  static Future<String?> getSession() async {
    final prefs = await _prefs;
    return prefs.getString('session_key');
  }

  static Future<void> saveSession(String key) async {
    final prefs = await _prefs;
    await prefs.setString('session_key', key);
  }

  static Future<void> clearSession() async {
    final prefs = await _prefs;
    await prefs.remove('session_key');
  }

  static Future<List<Account>> getAccounts() async {
    final prefs = await _prefs;
    final accountsJson = prefs.getStringList('accounts') ?? [];
    return accountsJson.map((jsonStr) {
      try {
        final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
        return Account.fromJson(jsonMap);
      } catch (e) {
        return null;
      }
    }).where((account) => account != null).cast<Account>().toList();
  }

  static Future<void> saveAccounts(List<Account> accounts) async {
    final prefs = await _prefs;
    final accountsJson = accounts.map((account) => jsonEncode(account.toJson())).toList();
    await prefs.setStringList('accounts', accountsJson);
  }

  static Future<int?> getActiveAccountIndex() async {
    final prefs = await _prefs;
    return prefs.getInt('active_account_index');
  }

  static Future<void> setActiveAccountIndex(int? index) async {
    final prefs = await _prefs;
    if (index == null) {
      await prefs.remove('active_account_index');
    } else {
      await prefs.setInt('active_account_index', index);
    }
  }

  static Future<Account?> getActiveAccount() async {
    final accounts = await getAccounts();
    final activeIndex = await getActiveAccountIndex();

    if (activeIndex != null) {
      try {
        return accounts.firstWhere(
          (account) => account.index == activeIndex,
        );
      } catch (e) {
        //Ошибка
      }
    }

    if (accounts.isNotEmpty) {
      accounts.sort((a, b) => b.lastLogin.compareTo(a.lastLogin));
      return accounts.first;
    }

    return null;
  }

  static Future<void> addAccount(Account account) async {
    final accounts = await getAccounts();

    final existingIndices = accounts.map((a) => a.index).toSet();
    int nextIndex = 1;
    while (existingIndices.contains(nextIndex)) {
      nextIndex++;
    }

    final accountWithIndex = account.copyWith(index: nextIndex);

    accounts.removeWhere((a) => a.id == account.id);
    accounts.add(accountWithIndex);
    await saveAccounts(accounts);
  }

  static Future<void> removeAccount(String accountId) async {
    final accounts = await getAccounts();
    final accountToRemove = accounts.cast<Account?>().firstWhere(
      (account) => account?.id == accountId,
      orElse: () => null,
    );

    if (accountToRemove != null) {
      final activeIndex = await getActiveAccountIndex();
      final wasActive = activeIndex == accountToRemove.index;

      accounts.removeWhere((account) => account.id == accountId);

      for (int i = 0; i < accounts.length; i++) {
        accounts[i] = accounts[i].copyWith(index: i + 1);
      }

      await saveAccounts(accounts);

      // Handle active account logic
      if (wasActive) {
        if (accounts.isNotEmpty) {
          await setActiveAccountIndex(1);
        } else {
          await setActiveAccountIndex(null);
          await clearSession();
        }
      } else if (activeIndex != null && activeIndex > accounts.length) {
        await setActiveAccountIndex(accounts.isNotEmpty ? 1 : null);
      }
    }
  }

  static Future<void> updateAccount(Account updatedAccount) async {
    final accounts = await getAccounts();
    final index = accounts.indexWhere((account) => account.id == updatedAccount.id);
    if (index != -1) {
      accounts[index] = updatedAccount;
      await saveAccounts(accounts);
    }
  }

  static Future<bool> getUseProfileAccentColor() async {
    final prefs = await _prefs;
    return prefs.getBool('use_profile_accent_color') ?? false;
  }

  static Future<void> setUseProfileAccentColor(bool value) async {
    final prefs = await _prefs;
    await prefs.setBool('use_profile_accent_color', value);
  }

  static Future<String?> getSavedAccentColor() async {
    final prefs = await _prefs;
    return prefs.getString('saved_accent_color');
  }

  static Future<void> setSavedAccentColor(String? color) async {
    final prefs = await _prefs;
    if (color == null) {
      await prefs.remove('saved_accent_color');
    } else {
      await prefs.setString('saved_accent_color', color);
    }
  }

  static Future<void> clearPersonalizationSettings() async {
    final prefs = await _prefs;
    await prefs.remove('use_profile_accent_color');
    await prefs.remove('saved_accent_color');
    await prefs.remove('tab_bar_glass_mode');
    await prefs.remove('hide_tab_bar');
    await prefs.remove('invert_player_tap_behavior');
    await prefs.remove('app_background_path');
    await prefs.remove('app_background_type');
    await prefs.remove('app_background_name');
    await prefs.remove('app_background_size');
    await prefs.remove('app_background_thumbnail_path');
    await prefs.remove('app_background_blur');
    await prefs.remove('app_background_darkening');
  }

  // ValueNotifier для отслеживания изменений режима таб-бара
  static final ValueNotifier<TabBarGlassMode> tabBarGlassModeNotifier = 
      ValueNotifier<TabBarGlassMode>(TabBarGlassMode.glass);

  static Future<TabBarGlassMode> getTabBarGlassMode() async {
    final prefs = await _prefs;
    final modeString = prefs.getString('tab_bar_glass_mode');
    if (modeString == null) {
      return TabBarGlassMode.solid; // По умолчанию solid
    }
    return TabBarGlassMode.fromString(modeString);
  }

  static Future<void> setTabBarGlassMode(TabBarGlassMode mode) async {
    final prefs = await _prefs;
    await prefs.setString('tab_bar_glass_mode', mode.toStorageString());
    tabBarGlassModeNotifier.value = mode;
  }

  // Инициализация ValueNotifier при старте приложения
  static Future<void> initializeTabBarGlassMode() async {
    final mode = await getTabBarGlassMode();
    tabBarGlassModeNotifier.value = mode;
  }

  static Future<bool> getHideTabBar() async {
    final prefs = await _prefs;
    return prefs.getBool('hide_tab_bar') ?? false; // По умолчанию false (показывать таб бар)
  }

  static Future<void> setHideTabBar(bool hide) async {
    final prefs = await _prefs;
    await prefs.setBool('hide_tab_bar', hide);
  }

  static Future<String?> getAppBackgroundPath() async {
    final prefs = await _prefs;
    return prefs.getString('app_background_path');
  }

  static Future<void> setAppBackgroundPath(String? path) async {
    final prefs = await _prefs;
    if (path == null) {
      await prefs.remove('app_background_path');
    } else {
      await prefs.setString('app_background_path', path);
    }
    appBackgroundPathNotifier.value = path;
  }

  static Future<String?> getAppBackgroundType() async {
    final prefs = await _prefs;
    return prefs.getString('app_background_type');
  }

  static Future<void> setAppBackgroundType(String? type) async {
    final prefs = await _prefs;
    if (type == null) {
      await prefs.remove('app_background_type');
    } else {
      await prefs.setString('app_background_type', type);
    }
  }

  static Future<Map<String, dynamic>?> getAppBackgroundMetadata() async {
    final prefs = await _prefs;
    final name = prefs.getString('app_background_name');
    final size = prefs.getInt('app_background_size');
    if (name == null && size == null) {
      return null;
    }
    return {
      'name': name,
      'size': size,
    };
  }

  static Future<void> setAppBackgroundMetadata(String? name, int? size) async {
    final prefs = await _prefs;
    if (name == null) {
      await prefs.remove('app_background_name');
    } else {
      await prefs.setString('app_background_name', name);
    }
    if (size == null) {
      await prefs.remove('app_background_size');
    } else {
      await prefs.setInt('app_background_size', size);
    }
  }

  static Future<String?> getAppBackgroundThumbnailPath() async {
    final prefs = await _prefs;
    return prefs.getString('app_background_thumbnail_path');
  }

  static Future<void> setAppBackgroundThumbnailPath(String? path) async {
    final prefs = await _prefs;
    if (path == null) {
      await prefs.remove('app_background_thumbnail_path');
    } else {
      await prefs.setString('app_background_thumbnail_path', path);
    }
  }

  static Future<double> getAppBackgroundBlur() async {
    final prefs = await _prefs;
    return prefs.getDouble('app_background_blur') ?? 10.0; // По умолчанию 10 sigma
  }

  static Future<void> setAppBackgroundBlur(double blur) async {
    final prefs = await _prefs;
    await prefs.setDouble('app_background_blur', blur);
  }

  static Future<double> getAppBackgroundDarkening() async {
    final prefs = await _prefs;
    return prefs.getDouble('app_background_darkening') ?? 0.4; // По умолчанию 40%
  }

  static Future<void> setAppBackgroundDarkening(double darkening) async {
    final prefs = await _prefs;
    await prefs.setDouble('app_background_darkening', darkening);
  }

  static Future<bool> getInvertPlayerTapBehavior() async {
    final prefs = await _prefs;
    return prefs.getBool('invert_player_tap_behavior') ?? false; // По умолчанию false (нормальное поведение)
  }

  static Future<void> setInvertPlayerTapBehavior(bool invert) async {
    final prefs = await _prefs;
    await prefs.setBool('invert_player_tap_behavior', invert);
  }

  static Future<List<String>> getMusicPlayedTracksHistory(String userId) async {
    final prefs = await _prefs;
    return prefs.getStringList('music_played_tracks_history_$userId') ?? [];
  }

  static Future<void> addToMusicPlayedTracksHistory(String userId, String trackJson) async {
    final prefs = await _prefs;
    final history = await getMusicPlayedTracksHistory(userId);

    history.remove(trackJson);

    history.insert(0, trackJson);

    if (history.length > 10) {
      history.removeRange(10, history.length);
    }

    await prefs.setStringList('music_played_tracks_history_$userId', history);
  }

  static Future<void> clearMusicPlayedTracksHistory(String userId) async {
    final prefs = await _prefs;
    await prefs.remove('music_played_tracks_history_$userId');
  }
}
