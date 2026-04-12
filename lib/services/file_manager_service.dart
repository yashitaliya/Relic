import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import 'saf_service.dart';

class FileManagerService {
  final SafService _safService = SafService();

  bool get _isDarwin => !kIsWeb && (Platform.isIOS || Platform.isMacOS);

  bool _isDarwinSmartAlbum(AssetPathEntity album) {
    final type = album.albumTypeEx?.darwin?.type;
    return type == PMDarwinAssetCollectionType.smartAlbum;
  }

  Future<AssetPathEntity?> _findAlbumByName(String name) async {
    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.common,
      hasAll: false,
    );

    for (final a in albums) {
      if (_isDarwin && _isDarwinSmartAlbum(a)) continue;
      if (a.name.toLowerCase() == name.toLowerCase()) {
        return a;
      }
    }
    return null;
  }

  /// Rename an image/video file
  ///
  /// - Android: uses SAF.
  /// - iOS: not supported by Photos APIs.
  Future<AssetEntity?> renameImage(AssetEntity entity, String newName) async {
    if (_isDarwin) {
      throw Exception('Renaming is not supported on iOS');
    }

    try {
      final success = await _safService.renameFile(entity, newName);
      if (success) {
        await PhotoManager.clearFileCache();
        return null;
      }
      throw Exception('SAF rename failed');
    } catch (e) {
      throw Exception('Failed to rename: $e');
    }
  }

  /// Move image to another album/folder.
  ///
  /// - Android: real file move via SAF (copy+delete).
  /// - iOS: "move" means add to target album, then remove from [fromAlbum] when possible.
  Future<AssetEntity?> moveImageToFolder(
    AssetEntity entity,
    String targetFolderName, {
    AssetPathEntity? fromAlbum,
  }) async {
    if (_isDarwin) {
      final targetAlbum = await _findAlbumByName(targetFolderName);
      if (targetAlbum == null) {
        throw Exception('Target album not found');
      }

      await PhotoManager.editor.copyAssetToPath(
        asset: entity,
        pathEntity: targetAlbum,
      );

      if (fromAlbum != null && !fromAlbum.isAll) {
        await PhotoManager.editor.darwin.removeAssetsInAlbum([
          entity,
        ], fromAlbum);
      }

      await PhotoManager.clearFileCache();
      return null;
    }

    try {
      final success = await _safService.moveFile(entity, targetFolderName);
      if (success) {
        await PhotoManager.clearFileCache();
        return null;
      }
      throw Exception('SAF move failed');
    } catch (e) {
      throw Exception('Failed to move: $e');
    }
  }

  /// Copy image to another album/folder.
  ///
  /// - Android: real file copy via SAF.
  /// - iOS: adds the asset to the target album (soft link in Photos).
  Future<AssetEntity?> copyImageToFolder(
    AssetEntity entity,
    String targetFolderName,
  ) async {
    if (_isDarwin) {
      final targetAlbum = await _findAlbumByName(targetFolderName);
      if (targetAlbum == null) {
        throw Exception('Target album not found');
      }

      await PhotoManager.editor.copyAssetToPath(
        asset: entity,
        pathEntity: targetAlbum,
      );

      await PhotoManager.clearFileCache();
      return null;
    }

    try {
      final success = await _safService.copyFile(entity, targetFolderName);
      if (success) {
        await PhotoManager.clearFileCache();
        return null;
      }
      throw Exception('SAF copy failed');
    } catch (e) {
      throw Exception('Failed to copy: $e');
    }
  }

  /// Create a new folder/album.
  ///
  /// - Android: creates a real filesystem folder under the SAF root.
  /// - iOS: creates a Photos album.
  Future<bool> createFolderIfNotExists(String folderName) async {
    try {
      if (_isDarwin) {
        final existing = await _findAlbumByName(folderName);
        if (existing != null) {
          return true;
        }

        final created = await PhotoManager.editor.darwin.createAlbum(
          folderName,
        );
        await PhotoManager.clearFileCache();
        return created != null;
      }

      final success = await _safService.createFolder(folderName);
      if (success) {
        await PhotoManager.clearFileCache();
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to create folder: $e');
    }
  }

  /// Rename an existing folder in Pictures
  Future<bool> renameFolder(String oldName, String newName) async {
    try {
      final success = await _safService.renameFolder(oldName, newName);
      if (success) {
        await PhotoManager.clearFileCache();
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Failed to rename folder: $e');
    }
  }

  /// Get list of folders/albums.
  ///
  /// Note: On iOS, Smart Albums (Favorites/Screenshots/etc) can't be targets for add/remove.
  Future<List<String>> getPicturesFolders() async {
    try {
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
        filterOption: FilterOptionGroup(containsPathModified: true),
      );

      final pictureFolders = <String>[];
      for (final album in albums) {
        if (album.isAll || album.name == 'Recent' || album.name == 'Recents') {
          continue;
        }
        if (_isDarwin && _isDarwinSmartAlbum(album)) {
          continue;
        }
        pictureFolders.add(album.name);
      }

      return pictureFolders;
    } catch (e) {
      throw Exception('Failed to get folders: $e');
    }
  }
}
