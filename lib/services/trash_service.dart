import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TrashService {
  static const String _trashKey = 'relic_trash_bin';

  // Singleton pattern
  static final TrashService _instance = TrashService._internal();
  factory TrashService() => _instance;
  TrashService._internal();

  Future<List<String>> getTrashedPhotoIds() async {
    final prefs = await SharedPreferences.getInstance();
    final String? trashJson = prefs.getString(_trashKey);
    if (trashJson == null) return [];

    try {
      final decoded = jsonDecode(trashJson);
      if (decoded is List) {
        // Migration: Convert old list format to map
        final map = {
          for (var id in decoded) id: DateTime.now().millisecondsSinceEpoch,
        };
        await prefs.setString(_trashKey, jsonEncode(map));
        return map.keys.cast<String>().toList();
      } else if (decoded is Map) {
        return decoded.keys.cast<String>().toList();
      }
    } catch (e) {
      return [];
    }
    return [];
  }

  Future<void> moveToTrash(String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> currentTrash = await _getTrashMap();

    if (!currentTrash.containsKey(photoId)) {
      currentTrash[photoId] = DateTime.now().millisecondsSinceEpoch;
      await prefs.setString(_trashKey, jsonEncode(currentTrash));
    }
  }

  Future<void> restoreFromTrash(String photoId) async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> currentTrash = await _getTrashMap();

    if (currentTrash.containsKey(photoId)) {
      currentTrash.remove(photoId);
      await prefs.setString(_trashKey, jsonEncode(currentTrash));
    }
  }

  Future<void> deletePermanently(String photoId) async {
    await restoreFromTrash(photoId);
  }

  Future<bool> isTrashed(String photoId) async {
    final Map<String, dynamic> currentTrash = await _getTrashMap();
    return currentTrash.containsKey(photoId);
  }

  Future<List<String>> cleanupOldItems() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, dynamic> currentTrash = await _getTrashMap();
    final now = DateTime.now().millisecondsSinceEpoch;
    final thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;

    final List<String> deletedIds = [];
    final Map<String, dynamic> newTrash = {};

    currentTrash.forEach((key, value) {
      final timestamp = value as int;
      if (now - timestamp < thirtyDaysMs) {
        newTrash[key] = value;
      } else {
        deletedIds.add(key);
      }
    });

    if (deletedIds.isNotEmpty) {
      await prefs.setString(_trashKey, jsonEncode(newTrash));
    }

    return deletedIds;
  }

  /// Get the number of days remaining before a photo is permanently deleted
  /// Returns null if photo is not in trash
  Future<int?> getDaysRemaining(String photoId) async {
    final Map<String, dynamic> currentTrash = await _getTrashMap();
    if (!currentTrash.containsKey(photoId)) return null;

    final timestamp = currentTrash[photoId] as int;
    final trashedDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final daysPassed = now.difference(trashedDate).inDays;
    final daysRemaining = 30 - daysPassed;

    return daysRemaining > 0 ? daysRemaining : 0;
  }

  /// Get the date when a photo was moved to trash
  Future<DateTime?> getTrashedDate(String photoId) async {
    final Map<String, dynamic> currentTrash = await _getTrashMap();
    if (!currentTrash.containsKey(photoId)) return null;

    final timestamp = currentTrash[photoId] as int;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  Future<Map<String, dynamic>> _getTrashMap() async {
    final prefs = await SharedPreferences.getInstance();
    final String? trashJson = prefs.getString(_trashKey);
    if (trashJson == null) return {};

    try {
      final decoded = jsonDecode(trashJson);
      if (decoded is List) {
        // Migration on read
        return {
          for (var id in decoded) id: DateTime.now().millisecondsSinceEpoch,
        };
      } else if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      return {};
    }
    return {};
  }
}
