import 'package:flutter/material.dart';
import '../services/file_manager_service.dart';

class AlbumPickerDialog extends StatefulWidget {
  final String title;
  final List<String>? excludeFolders;

  const AlbumPickerDialog({
    super.key,
    required this.title,
    this.excludeFolders,
  });

  @override
  State<AlbumPickerDialog> createState() => _AlbumPickerDialogState();
}

class _AlbumPickerDialogState extends State<AlbumPickerDialog> {
  final FileManagerService _fileManager = FileManagerService();
  List<String> _folders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    try {
      final folders = await _fileManager.getPicturesFolders();
      if (mounted) {
        setState(() {
          _folders = folders
              .where((f) => !(widget.excludeFolders?.contains(f) ?? false))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
                ),
              )
            : _folders.isEmpty
                ? const Center(child: Text('No other albums found'))
                : ListView.builder(
                    itemCount: _folders.length,
                    itemBuilder: (context, index) {
                      final folder = _folders[index];
                      return ListTile(
                        leading:
                            const Icon(Icons.folder, color: Color(0xFFF37121)),
                        title: Text(folder),
                        onTap: () => Navigator.pop(context, folder),
                      );
                    },
                  ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
