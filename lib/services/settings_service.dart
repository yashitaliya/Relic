import 'dart:async';

import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesController.stream;

  static void _notifyChanged() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  static const String _gridSizeKey = 'grid_size';
  static const String _sortOrderKey = 'sort_order';
  static const String _albumSortPrefix = 'album_sort_order_';

  Future<int> getGridSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_gridSizeKey) ?? 3;
  }

  Future<void> setGridSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_gridSizeKey, size);
    _notifyChanged();
  }

  Future<String> getSortOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_sortOrderKey) ?? 'newest';
  }

  Future<void> setSortOrder(String order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sortOrderKey, order);
    _notifyChanged();
  }

  Future<String> getAlbumSortOrder(String albumId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_albumSortPrefix$albumId') ?? 'newest';
  }

  Future<void> setAlbumSortOrder(String albumId, String order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_albumSortPrefix$albumId', order);
    _notifyChanged();
  }

  Future<int> getStartPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('start_page') ?? 0; // 0 for Home, 1 for Albums
  }

  Future<void> setStartPage(int pageIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('start_page', pageIndex);
    _notifyChanged();
  }

  Future<void> clearCache() async {
    await PhotoManager.clearFileCache();
    _notifyChanged();
  }

  static const String _appLockKey = 'app_lock_enabled';

  Future<bool> getAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_appLockKey) ?? false;
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_appLockKey, enabled);
    _notifyChanged();
  }

  static const String _albumsGridSizeKey = 'albums_grid_size';

  Future<int> getAlbumsGridSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_albumsGridSizeKey) ?? 2;
  }

  Future<void> setAlbumsGridSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_albumsGridSizeKey, size);
    _notifyChanged();
  }
}
