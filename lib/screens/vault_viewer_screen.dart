import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'dart:typed_data';
import '../database/vault_database.dart';
import '../services/vault_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'dart:io';
import '../widgets/glass_app_bar.dart';

class VaultViewerScreen extends StatefulWidget {
  final VaultFile file;

  const VaultViewerScreen({super.key, required this.file});

  @override
  State<VaultViewerScreen> createState() => _VaultViewerScreenState();
}

class _VaultViewerScreenState extends State<VaultViewerScreen> {
  final VaultService _vaultService = VaultService();
  Uint8List? _decryptedBytes;
  bool _isLoading = true;
  late final Player _player;
  late final VideoController _controller;
  File? _tempVideoFile;

  @override
  void initState() {
    super.initState();
    if (widget.file.type == 'video') {
      _initVideo();
    } else {
      _decryptImage();
    }
  }

  Future<void> _decryptImage() async {
    final bytes = await _vaultService.getDecryptedBytes(widget.file);
    if (mounted) {
      setState(() {
        _decryptedBytes = bytes;
        _isLoading = false;
      });
    }
  }

  Future<void> _initVideo() async {
    // For video, we need to write decrypted bytes to a temp file for the player
    // This is a security trade-off for performance/compatibility
    final bytes = await _vaultService.getDecryptedBytes(widget.file);
    if (bytes == null) {
      setState(() => _isLoading = false);
      return;
    }

    final tempDir = await Directory.systemTemp.createTemp();
    _tempVideoFile = File('${tempDir.path}/temp_video.mp4');
    await _tempVideoFile!.writeAsBytes(bytes);

    _player = Player();
    _controller = VideoController(_player);
    await _player.open(Media(_tempVideoFile!.path));

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    if (widget.file.type == 'video') {
      _player.dispose();
      _tempVideoFile?.delete(); // Clean up temp file
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: '',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B3E26)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: widget.file.type == 'video'
                  ? Video(controller: _controller)
                  : _decryptedBytes != null
                  ? PhotoView(
                      imageProvider: MemoryImage(_decryptedBytes!),
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 2,
                    )
                  : const Text(
                      'Error loading image',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
    );
  }
}
