import 'dart:io';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/vault_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';
import 'saf_service.dart';

class VaultService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _keyStorageKey = 'vault_encryption_key';
  static const platform = MethodChannel('com.example.relic/secure');

  // Singleton
  static final VaultService _instance = VaultService._internal();
  factory VaultService() => _instance;
  VaultService._internal();

  // Get or create encryption key
  Future<encrypt.Key> _getEncryptionKey() async {
    String? keyString = await _storage.read(key: _keyStorageKey);

    if (keyString == null) {
      // Generate new 32-byte (256-bit) key
      final key = encrypt.Key.fromSecureRandom(32);
      await _storage.write(key: _keyStorageKey, value: key.base64);
      return key;
    }

    return encrypt.Key.fromBase64(keyString);
  }

  // Get vault directory (hidden from gallery)
  Future<Directory> _getVaultDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(path.join(appDir.path, '.vault'));

    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
      // Create .nomedia file just in case
      await File(path.join(vaultDir.path, '.nomedia')).create();
    }

    return vaultDir;
  }

  // Generate thumbnail
  Future<Uint8List?> _generateThumbnail(File file, String type) async {
    try {
      if (type == 'video') {
        // For video, we might need a video thumbnail generator package
        // For now, return null or a placeholder if possible
        // Implementing video thumbnail is complex without extra plugins like video_thumbnail
        // We'll skip for now or use a generic icon in UI if null
        return null;
      } else {
        final bytes = await file.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image == null) return null;

        // Resize to 200px width
        final thumbnail = img.copyResize(image, width: 200);
        return Uint8List.fromList(img.encodeJpg(thumbnail, quality: 70));
      }
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  // Encrypt file and save to vault (does NOT delete original)
  Future<VaultFile?> encryptFile(File originalFile) async {
    if (!await originalFile.exists()) return null;

    final key = await _getEncryptionKey();
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    // Generate thumbnail before encryption
    final type = _getFileType(originalFile.path);
    final thumbnail = await _generateThumbnail(originalFile, type);

    // Read file bytes
    final bytes = await originalFile.readAsBytes();

    // Encrypt
    final encrypted = encrypter.encryptBytes(bytes, iv: iv);

    // Save to vault
    final vaultDir = await _getVaultDirectory();
    final uuid = const Uuid().v4();
    final encryptedFileName = '$uuid.enc';
    final encryptedFile = File(path.join(vaultDir.path, encryptedFileName));

    // Store IV + Encrypted Data
    final combined = Uint8List(iv.bytes.length + encrypted.bytes.length);
    combined.setAll(0, iv.bytes);
    combined.setAll(iv.bytes.length, encrypted.bytes);

    await encryptedFile.writeAsBytes(combined);

    // Save metadata to DB
    final vaultFile = VaultFile(
      id: uuid,
      originalPath: originalFile.path,
      encryptedPath: encryptedFile.path,
      type: type,
      dateAdded: DateTime.now(),
      thumbnail: thumbnail,
    );

    await VaultDatabase.instance.insertFile(vaultFile);
    return vaultFile;
  }

  // Hide file (Encrypt & Move)
  Future<void> hideFile(AssetEntity asset) async {
    final file = await asset.file;
    if (file == null) return;
    final originalName = await asset.titleAsync;
    final createdAt = asset.createDateTime;

    final vaultFile = await encryptFile(file);
    if (vaultFile != null) {
      final enrichedVaultFile = VaultFile(
        id: vaultFile.id,
        originalPath: vaultFile.originalPath,
        encryptedPath: vaultFile.encryptedPath,
        type: vaultFile.type,
        dateAdded: vaultFile.dateAdded,
        thumbnail: vaultFile.thumbnail,
        originalFilename: originalName.isEmpty ? null : originalName,
        originalCreatedAt: createdAt,
      );
      await VaultDatabase.instance.deleteFile(vaultFile.id);
      await VaultDatabase.instance.insertFile(enrichedVaultFile);

      // Delete original file using SAF
      // We need to use SafService to delete the file to avoid permission issues
      try {
        // Use the SafService to delete file
        final safService = SafService();
        final success = await safService.deleteFile(asset);

        if (!success) {
          debugPrint(
            'SAF delete returned false for ${asset.id}, trying PhotoManager delete',
          );
          try {
            await PhotoManager.editor.deleteWithIds([asset.id]);
          } catch (e) {
            debugPrint('Failed to delete via PhotoManager: $e');
          }
        }
      } catch (e) {
        debugPrint('Exception during file deletion: $e');
        // Fallback: try PhotoManager deletion
        try {
          await PhotoManager.editor.deleteWithIds([asset.id]);
        } catch (_) {
          // If all delete attempts fail, it's okay - file is encrypted in vault anyway
        }
      }
    }
  }

  // Unhide file (Decrypt & Restore)
  Future<void> unhideFile(VaultFile vaultFile) async {
    final encryptedFile = File(vaultFile.encryptedPath);
    if (!await encryptedFile.exists()) return;

    final key = await _getEncryptionKey();
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    // Read bytes
    final allBytes = await encryptedFile.readAsBytes();

    // Extract IV (first 16 bytes)
    final ivBytes = allBytes.sublist(0, 16);
    final iv = encrypt.IV(ivBytes);

    // Extract Encrypted Data
    final encryptedBytes = allBytes.sublist(16);
    final encrypted = encrypt.Encrypted(encryptedBytes);

    // Decrypt
    final decryptedBytes = encrypter.decryptBytes(encrypted, iv: iv);

    final tempDir = await getTemporaryDirectory();
    final fileName =
        vaultFile.originalFilename ?? path.basename(vaultFile.originalPath);
    final tempFile = File(path.join(tempDir.path, '${vaultFile.id}_$fileName'));
    await tempFile.writeAsBytes(decryptedBytes);

    if (vaultFile.type == 'video') {
      await PhotoManager.editor.saveVideo(
        tempFile,
        title: fileName,
        creationDate: vaultFile.originalCreatedAt,
      );
    } else {
      await PhotoManager.editor.saveImageWithPath(
        tempFile.path,
        title: fileName,
        creationDate: vaultFile.originalCreatedAt,
      );
    }

    if (Platform.isAndroid) {
      await _scanFile(tempFile.path);
    }

    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    // Delete from vault and DB
    await encryptedFile.delete();
    await VaultDatabase.instance.deleteFile(vaultFile.id);
  }

  // Force MediaScanner to scan a file
  Future<void> _scanFile(String path) async {
    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('scanFile', {'path': path});
      } on PlatformException catch (e) {
        debugPrint("Failed to scan file: '${e.message}'.");
      }
    }
  }

  // Get decrypted bytes for viewing
  Future<Uint8List?> getDecryptedBytes(VaultFile vaultFile) async {
    final encryptedFile = File(vaultFile.encryptedPath);
    if (!await encryptedFile.exists()) return null;

    final key = await _getEncryptionKey();
    final encrypter = encrypt.Encrypter(encrypt.AES(key));

    final allBytes = await encryptedFile.readAsBytes();
    final ivBytes = allBytes.sublist(0, 16);
    final iv = encrypt.IV(ivBytes);
    final encryptedBytes = allBytes.sublist(16);
    final encrypted = encrypt.Encrypted(encryptedBytes);

    return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
  }

  String _getFileType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    if (['.mp4', '.mov', '.avi', '.mkv'].contains(ext)) {
      return 'video';
    }
    return 'image';
  }
}
