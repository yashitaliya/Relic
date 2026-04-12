import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'classification_service.dart';

class SearchDataService extends ChangeNotifier {
  static final SearchDataService _instance = SearchDataService._internal();
  static SearchDataService get instance => _instance;

  SearchDataService._internal();

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  Map<String, List<AssetEntity>> _placeGroups = {};
  Map<String, List<AssetEntity>> get placeGroups => _placeGroups;

  Map<String, List<AssetEntity>> _typeGroups = {
    'Selfies': [],
    'Nature': [],
    'Sky': [],
    'Night': [],
    // 'Food': [], // Removed as per user request
  };
  Map<String, List<AssetEntity>> get typeGroups => _typeGroups;

  // Cache to avoid re-analyzing
  Map<String, dynamic> _cache = {};

  DateTime? _lastScanAt;
  int? _lastScannedAssetCount;
  static const Duration _minScanInterval = Duration(minutes: 2);

  Future<void> startScan() async {
    if (_isScanning) return;

    final currentAssetCount = await _getCurrentAssetCount();

    final recentlyScanned =
        _lastScanAt != null &&
        DateTime.now().difference(_lastScanAt!) < _minScanInterval;
    final assetCountUnchanged =
        _lastScannedAssetCount != null &&
        currentAssetCount == _lastScannedAssetCount;

    // Avoid re-running expensive scan when nothing changed.
    if (recentlyScanned && assetCountUnchanged) {
      return;
    }

    // Check permissions first
    var status = await Permission.accessMediaLocation.status;
    if (!status.isGranted) {
      // If not granted, we might not be able to get location, but we can still scan types.
      // However, usually we want to wait for permission.
      // For now, let's assume permission is handled by UI (HomeScreen/SearchScreen).
      // If strictly needed, we can request it, but services shouldn't trigger UI popups ideally.
    }

    _isScanning = true;
    notifyListeners();

    try {
      await _loadSmartData(currentAssetCount);
      _lastScannedAssetCount = currentAssetCount;
      _lastScanAt = DateTime.now();
    } catch (e) {
      debugPrint('SearchDataService: Error during scan: $e');
    } finally {
      _isScanning = false;
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  Future<int> _getCurrentAssetCount() async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );

    if (albums.isEmpty) {
      return 0;
    }

    return albums.first.assetCountAsync;
  }

  Future<void> _loadSmartData(int totalCount) async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
    );

    if (albums.isEmpty) {
      debugPrint('SearchDataService: No albums found');
      return;
    }

    final recentAlbum = albums.first;
    debugPrint('SearchDataService: Starting scan of $totalCount photos');

    // Load ALL assets
    final allAssets = await recentAlbum.getAssetListRange(
      start: 0,
      end: totalCount,
    );
    final assets = allAssets.where((a) => a.type == AssetType.image).toList();

    // 1. Load Cache
    final prefs = await SharedPreferences.getInstance();
    final String? cachedDataString = prefs.getString('smart_search_cache_v5');

    if (cachedDataString != null) {
      try {
        _cache = jsonDecode(cachedDataString);
        _populateGroupsFromCache(assets);
        notifyListeners(); // Show cached data immediately
      } catch (e) {
        debugPrint('SearchDataService: Error decoding cache: $e');
      }
    }

    // 2. Identify New Assets
    final newAssets = assets.where((a) => !_cache.containsKey(a.id)).toList();
    debugPrint(
      'SearchDataService: Found ${newAssets.length} new assets to scan',
    );

    // 3. Process New Assets
    if (newAssets.isNotEmpty) {
      _isAnalyzing = true;
      notifyListeners();
      await _processBatch(newAssets, prefs);
    } else {
      debugPrint(
        'SearchDataService: All ${assets.length} assets already cached. Skipping scan.',
      );
    }
  }

  void _populateGroupsFromCache(List<AssetEntity> assets) {
    // Reset groups
    _placeGroups = {};
    _typeGroups = {'Selfies': [], 'Nature': [], 'Sky': [], 'Night': []};

    for (var asset in assets) {
      if (_cache.containsKey(asset.id)) {
        final data = _cache[asset.id];

        // Place
        if (data['place'] != null) {
          final placeKey = data['place'];
          if (!_placeGroups.containsKey(placeKey)) {
            _placeGroups[placeKey] = [];
          }
          _placeGroups[placeKey]!.add(asset);
        }

        // Type
        if (data['type'] != null) {
          final typeKey = data['type'];
          // Filter out 'Food'
          if (typeKey != 'Food' && _typeGroups.containsKey(typeKey)) {
            _typeGroups[typeKey]!.add(asset);
          }
        }
      }
    }
  }

  Future<void> _processBatch(
    List<AssetEntity> assets,
    SharedPreferences prefs,
  ) async {
    int analyzedCount = 0;
    bool cacheUpdated = false;

    for (var i = 0; i < assets.length; i++) {
      final asset = assets[i];
      final assetId = asset.id;

      // --- PLACE ANALYSIS ---
      double lat = 0;
      double lng = 0;
      try {
        final latLng = await asset.latlngAsync();
        if (latLng != null) {
          lat = latLng.latitude;
          lng = latLng.longitude;
        }
      } catch (e) {
        // ignore
      }

      String? placeKey;
      if (lat != 0 && lng != 0 && !lat.isNaN && !lng.isNaN) {
        try {
          placeKey = '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
          if (!_placeGroups.containsKey(placeKey)) {
            _placeGroups[placeKey] = [];
          }
          _placeGroups[placeKey]!.add(asset);
        } catch (e) {
          debugPrint('Error grouping place: $e');
        }
      }

      // --- TYPE ANALYSIS ---
      final path = (asset.relativePath ?? '').toLowerCase();
      bool categorized = false;
      String? typeKey;

      // Metadata Rules
      if (asset.width < asset.height &&
          (path.contains('front') || path.contains('selfie'))) {
        typeKey = 'Selfies';
        categorized = true;
      }

      // Pixel Analysis
      if (!categorized &&
          asset.type == AssetType.image &&
          analyzedCount < 500) {
        // Limit heavy analysis
        try {
          final bytes = await asset.thumbnailDataWithSize(
            const ThumbnailSize(64, 64),
          );
          if (bytes != null && bytes.isNotEmpty) {
            final detectedType = await compute(
              runClassificationInIsolate,
              bytes,
            );
            if (detectedType != null && detectedType != 'Food') {
              // Ignore Food
              typeKey = detectedType;
              categorized = true;
              analyzedCount++;
            }
          }
        } catch (e) {
          // ignore
        }
      }

      if (categorized && typeKey != null) {
        if (_typeGroups.containsKey(typeKey)) {
          _typeGroups[typeKey]!.add(asset);
        }
      }

      // Update Cache
      if (placeKey != null || typeKey != null) {
        _cache[assetId] = {'place': placeKey, 'type': typeKey};
        cacheUpdated = true;
      }

      // Notify UI incrementally every 20 items
      if (i > 0 && i % 20 == 0) {
        notifyListeners();
        await Future.delayed(Duration.zero); // Yield
      }
    }

    // Save Cache
    if (cacheUpdated) {
      prefs.setString('smart_search_cache_v5', jsonEncode(_cache));
      debugPrint('SearchDataService: Cache updated.');
    }

    notifyListeners(); // Final update
  }
}

// Top-level function for compute
Future<String?> runClassificationInIsolate(Uint8List bytes) async {
  return ClassificationService.analyzePixels(bytes);
}
