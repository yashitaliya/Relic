import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';

class SafService {
  static const platform = MethodChannel('com.example.relic/saf');

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<T?> _invokeSaf<T>(String method, [Object? arguments]) async {
    if (!_isAndroid) {
      return null;
    }

    try {
      return await platform.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }

  /// Request the user to pick the Pictures folder
  Future<void> openDocumentTree() async {
    await _invokeSaf<void>('openDocumentTree');
  }

  /// Check if we have a persisted URI
  Future<String?> getPersistedUri() async {
    return await _invokeSaf<String>('getPersistedUri');
  }

  /// Release the persisted URI (logout/reset)
  Future<bool> releasePersistedUri(String uri) async {
    return await _invokeSaf<bool>('releasePersistedUri', {'uri': uri}) ?? false;
  }

  /// Create a folder
  Future<bool> createFolder(String name) async {
    return await _invokeSaf<bool>('createFolder', {'name': name}) ?? false;
  }

  /// Request All Files Access (Android 11+)
  Future<void> requestAllFilesAccess() async {
    await _invokeSaf<void>('requestAllFilesAccess');
  }

  /// Check if All Files Access is granted
  Future<bool> hasAllFilesAccess() async {
    if (!_isAndroid) {
      return true;
    }

    return await _invokeSaf<bool>('checkAllFilesAccess') ?? false;
  }

  /// Rename a folder
  Future<bool> renameFolder(String oldName, String newName) async {
    return await _invokeSaf<bool>('renameFolder', {
          'oldName': oldName,
          'newName': newName,
        }) ??
        false;
  }

  /// Rename a file
  Future<bool> renameFile(AssetEntity entity, String newName) async {
    final file = await entity.file;
    if (file == null) return false;

    final folderName = _getFolderName(entity);
    final oldName = file.uri.pathSegments.last;

    // Ensure newName has extension
    final ext = oldName.split('.').last;
    final finalNewName = newName.endsWith('.$ext') ? newName : '$newName.$ext';

    return await _invokeSaf<bool>('renameFile', {
          'folder': folderName,
          'oldName': oldName,
          'newName': finalNewName,
        }) ??
        false;
  }

  /// Copy a file
  Future<bool> copyFile(AssetEntity asset, String targetFolderName) async {
    try {
      final file = await asset.file;
      if (file == null) return false;

      // We need the Content URI, but AssetEntity only gives us file path or ID.
      // However, we can construct the URI or use the file path if it's a content URI.
      // PhotoManager's getMediaUrl() might return a content URI.
      // Or we can use the 'id' to construct content://media/external/images/media/ID

      String? sourceUri;
      if (Platform.isAndroid) {
        // Construct MediaStore URI
        // This is a bit hacky but standard for Android MediaStore
        final type = asset.type == AssetType.video ? 'video' : 'images';
        sourceUri = 'content://media/external/$type/media/${asset.id}';
      } else {
        // Fallback for non-Android (not used here but for safety)
        sourceUri = file.uri.toString();
      }

      final targetName = await asset.titleAsync;

      final result = await _invokeSaf<bool>('copyFile', {
        'sourceUri': sourceUri,
        'targetFolder': targetFolderName,
        'targetName': targetName,
      });
      return result == true;
    } catch (e) {
      debugPrint('Error copying file via SAF: $e');
      return false;
    }
  }

  /// Move a file
  Future<bool> moveFile(AssetEntity asset, String targetFolderName) async {
    // Move = Copy + Delete
    final copySuccess = await copyFile(asset, targetFolderName);
    if (copySuccess) {
      // Try to delete original
      try {
        final success = await deleteFile(asset);
        if (!success) {
          // Fallback to PhotoManager delete if SAF delete fails (e.g. outside SAF root)
          final deleted = await PhotoManager.editor.deleteWithIds([asset.id]);
          return deleted.isNotEmpty;
        }
        return true;
      } catch (e) {
        debugPrint('Error deleting original after copy: $e');
        return false;
      }
    }
    return false;
  }

  /// Delete a file
  Future<bool> deleteFile(AssetEntity entity) async {
    final file = await entity.file;
    if (file == null) return false;

    // If we have All Files Access, use absolute path directly
    if (await hasAllFilesAccess()) {
      return await _invokeSaf<bool>('deleteFileByPath', {'path': file.path}) ??
          false;
    }

    final folderName = _getFolderName(entity);
    final name = file.uri.pathSegments.last;

    return await _invokeSaf<bool>('deleteFile', {
          'folder': folderName,
          'name': name,
        }) ??
        false;
  }

  String _getFolderName(AssetEntity entity) {
    // entity.relativePath usually looks like "Pictures/AlbumName/" or "DCIM/Camera/"
    // We assume the user picked "Pictures" as the root.
    // So we need to strip "Pictures/" from the start if present.
    var path = entity.relativePath ?? '';
    if (path.endsWith('/')) path = path.substring(0, path.length - 1);

    final parts = path.split('/');
    if (parts.isNotEmpty && parts.first.toLowerCase() == 'pictures') {
      if (parts.length > 1) {
        return parts.sublist(1).join('/');
      } else {
        return ''; // Root Pictures folder
      }
    }
    return path;
  }
}
