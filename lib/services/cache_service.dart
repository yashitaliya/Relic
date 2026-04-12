import 'dart:async';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/photo_model.dart';

/// Centralized caching service for the entire app
/// Handles caching of photos, thumbnails, AI responses, and album data
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // In-memory caches for fast access
  final Map<String, Uint8List> _thumbnailCache = {};
  final Map<String, Uint8List> _fullImageCache = {};
  final Map<String, dynamic> _dataCache = {};

  // Cache limits
  static const int _maxThumbnailCache = 500; // Keep 500 thumbnails in memory
  static const int _maxFullImageCache = 50; // Keep 50 full images in memory

  // LRU tracking
  final List<String> _thumbnailAccessOrder = [];
  final List<String> _fullImageAccessOrder = [];

  /// Cache a thumbnail image
  Future<void> cacheThumbnail(String id, Uint8List data) async {
    _thumbnailCache[id] = data;
    _updateAccessOrder(_thumbnailAccessOrder, id);
    _enforceLimit(_thumbnailCache, _thumbnailAccessOrder, _maxThumbnailCache);
  }

  /// Get cached thumbnail
  Uint8List? getThumbnail(String id) {
    final data = _thumbnailCache[id];
    if (data != null) {
      _updateAccessOrder(_thumbnailAccessOrder, id);
    }
    return data;
  }

  /// Cache a full-size image
  Future<void> cacheFullImage(String id, Uint8List data) async {
    _fullImageCache[id] = data;
    _updateAccessOrder(_fullImageAccessOrder, id);
    _enforceLimit(_fullImageCache, _fullImageAccessOrder, _maxFullImageCache);
  }

  /// Get cached full-size image
  Uint8List? getFullImage(String id) {
    final data = _fullImageCache[id];
    if (data != null) {
      _updateAccessOrder(_fullImageAccessOrder, id);
    }
    return data;
  }

  /// Cache generic data (albums, AI responses, etc.)
  Future<void> cacheData(String key, dynamic data) async {
    _dataCache[key] = {'data': data, 'timestamp': DateTime.now()};

    // Also persist to SharedPreferences for long-term storage
    final prefs = await SharedPreferences.getInstance();
    if (data is String) {
      await prefs.setString('cache_$key', data);
    } else if (data is List<String>) {
      await prefs.setStringList('cache_$key', data);
    }
    await prefs.setInt(
      'cache_${key}_timestamp',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get cached data
  Future<T?> getData<T>(String key, {Duration? maxAge}) async {
    // Check in-memory cache first
    final cached = _dataCache[key];
    if (cached != null) {
      final timestamp = cached['timestamp'] as DateTime;
      final age = DateTime.now().difference(timestamp);

      if (maxAge == null || age < maxAge) {
        return cached['data'] as T?;
      }
    }

    // Check SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final timestampMs = prefs.getInt('cache_${key}_timestamp');

    if (timestampMs != null) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      final age = DateTime.now().difference(timestamp);

      if (maxAge == null || age < maxAge) {
        if (T == String) {
          return prefs.getString('cache_$key') as T?;
        } else if (T == List<String>) {
          return prefs.getStringList('cache_$key') as T?;
        }
      }
    }

    return null;
  }

  /// Clear specific cache
  Future<void> clearCache(String key) async {
    _dataCache.remove(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cache_$key');
    await prefs.remove('cache_${key}_timestamp');
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    _thumbnailCache.clear();
    _fullImageCache.clear();
    _dataCache.clear();
    _thumbnailAccessOrder.clear();
    _fullImageAccessOrder.clear();

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('cache_'));
    for (var key in keys) {
      await prefs.remove(key);
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'thumbnailCount': _thumbnailCache.length,
      'fullImageCount': _fullImageCache.length,
      'dataCount': _dataCache.length,
      'thumbnailMemoryMB': _calculateMemoryUsage(_thumbnailCache),
      'fullImageMemoryMB': _calculateMemoryUsage(_fullImageCache),
    };
  }

  /// Update LRU access order
  void _updateAccessOrder(List<String> accessOrder, String id) {
    accessOrder.remove(id);
    accessOrder.add(id);
  }

  /// Enforce cache size limit using LRU eviction
  void _enforceLimit(
    Map<String, Uint8List> cache,
    List<String> accessOrder,
    int maxSize,
  ) {
    while (cache.length > maxSize) {
      final oldestId = accessOrder.removeAt(0);
      cache.remove(oldestId);
    }
  }

  /// Calculate memory usage in MB
  double _calculateMemoryUsage(Map<String, Uint8List> cache) {
    int totalBytes = 0;
    for (var data in cache.values) {
      totalBytes += data.length;
    }
    return totalBytes / (1024 * 1024);
  }

  /// Preload thumbnails for better UX
  Future<void> preloadThumbnails(List<PhotoModel> photos) async {
    for (var photo in photos.take(100)) {
      // Preload first 100
      if (!_thumbnailCache.containsKey(photo.id)) {
        try {
          final thumbnail = await photo.asset.thumbnailDataWithSize(
            const ThumbnailSize(200, 200),
          );
          if (thumbnail != null) {
            await cacheThumbnail(photo.id, thumbnail);
          }
        } catch (_) {
          // Silently fail for individual thumbnails
        }
      }
    }
  }
}
