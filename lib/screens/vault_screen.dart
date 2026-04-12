import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:async';
import '../database/vault_database.dart';
import '../services/vault_service.dart';
import '../services/photo_service.dart';

import 'vault_viewer_screen.dart';
import 'vault_import_screen.dart';
import '../services/auth_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final VaultService _vaultService = VaultService();
  static const platform = MethodChannel('com.example.relic/secure');
  List<VaultFile> _files = [];
  bool _isLoading = false;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  StreamSubscription<HiddenChange>? _hiddenSubscription;

  @override
  void initState() {
    super.initState();
    _secureScreen(true);
    _loadFiles();
    // Subscribe to hidden changes to refresh vault
    _hiddenSubscription = PhotoService.onHiddenChanged.listen(_onHiddenChanged);
  }

  void _onHiddenChanged(HiddenChange event) {
    if (!mounted) return;
    // If a photo was hidden, refresh the vault to show it
    if (event.isHidden) {
      _loadFiles();
    }
  }

  Future<void> _secureScreen(bool secure) async {
    // Block screenshots and recent apps preview
    if (Platform.isAndroid) {
      try {
        await platform.invokeMethod('secure', {'secure': secure});
      } on PlatformException catch (e) {
        debugPrint("Failed to set secure flag: '${e.message}'.");
      }
    }
  }

  @override
  void dispose() {
    // Allow screenshots again when leaving
    _secureScreen(false);
    // Clear vault flag
    AuthService().isInVault = false;
    // Cancel hidden changes subscription
    _hiddenSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final files = await VaultDatabase.instance.getAllFiles();
    setState(() {
      _files = files;
      _isLoading = false;
    });
  }

  Future<void> _addFiles() async {
    // Navigate to VaultImportScreen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VaultImportScreen()),
    );

    if (result == true) {
      _loadFiles(); // Refresh vault content
    }
  }

  Future<void> _unhideSelected() async {
    if (_selectedIds.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final count = _selectedIds.length;
      for (var id in _selectedIds) {
        final file = _files.firstWhere((f) => f.id == id);
        await _vaultService.unhideFile(file);
        // Emit unhidden change event
        PhotoService.emitHiddenChange(file.id, false);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unhidden $count item${count > 1 ? 's' : ''}'),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }

      // Refresh vault
      _selectedIds.clear();
      _isSelectionMode = false;
      await _loadFiles();

      // Navigate back to previous screen after a brief delay
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error unhiding files: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
        _isSelectionMode = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SafeArea(
                bottom: false,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isSelectionMode
                              ? '${_selectedIds.length} Selected'
                              : 'Vault',
                          style: const TextStyle(
                            color: Color(0xFF6B3E26),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            if (_isSelectionMode)
                              IconButton(
                                icon: const Icon(
                                  Icons.lock_open,
                                  color: Color(0xFFF37121),
                                ),
                                onPressed: _unhideSelected,
                              )
                            else
                              IconButton(
                                icon: const Icon(
                                  Icons.add,
                                  color: Color(0xFFF37121),
                                ),
                                onPressed: _addFiles,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
              ),
            )
          : _files.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Vault is empty',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _addFiles,
                    icon: const Icon(Icons.add, color: Color(0xFFF37121)),
                    label: const Text(
                      'Add Photos/Videos',
                      style: TextStyle(color: Color(0xFFF37121)),
                    ),
                  ),
                ],
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 110 + MediaQuery.of(context).padding.top + 12,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(8),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final file = _files[index];
                      final isSelected = _selectedIds.contains(file.id);

                      return GestureDetector(
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(file.id);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    VaultViewerScreen(file: file),
                              ),
                            );
                          }
                        },
                        onLongPress: () => _toggleSelection(file.id),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: file.thumbnail != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        file.thumbnail!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      file.type == 'video'
                                          ? Icons.movie
                                          : Icons.image,
                                      color: Colors.grey[600],
                                      size: 32,
                                    ),
                            ),
                            if (isSelected)
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFF37121,
                                  ).withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFF37121),
                                    width: 3,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }, childCount: _files.length),
                  ),
                ),
              ],
            ),
    );
  }
}
