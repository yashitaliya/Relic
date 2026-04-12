import 'package:flutter/material.dart';
import '../services/saf_service.dart';
import '../widgets/glass_app_bar.dart';

class SafSetupScreen extends StatefulWidget {
  const SafSetupScreen({super.key});

  @override
  State<SafSetupScreen> createState() => _SafSetupScreenState();
}

class _SafSetupScreenState extends State<SafSetupScreen> {
  final SafService _safService = SafService();
  bool _isLoading = false;
  String? _currentUri;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    setState(() => _isLoading = true);
    final uri = await _safService.getPersistedUri();
    setState(() {
      _currentUri = uri;
      _isLoading = false;
    });
  }

  Future<void> _requestPermission() async {
    try {
      await _safService.openDocumentTree();
      // The result comes back via onActivityResult in MainActivity,
      // but we need to poll or wait for the UI to resume to check if it worked.
      // Since `openDocumentTree` is just launching an intent, we don't get a direct awaitable result
      // in the same way unless we set up a result listener, but our service just invokes method.
      // However, MainActivity sends the result back to `pendingResult` if we waited.
      // Wait, my `SafService.dart` `openDocumentTree` awaits the method channel.
      // And `MainActivity.kt` `openDocumentTree` sets `pendingResult`.
      // So `await _safService.openDocumentTree()` WILL wait for the user to pick!

      await _checkPermission();

      if (mounted && _currentUri != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission granted successfully!')),
        );
        Navigator.of(context).pop(); // Go back if successful
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Storage Setup',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF6B3E26)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.only(
          top: kToolbarHeight + MediaQuery.of(context).padding.top + 24,
          left: 24,
          right: 24,
          bottom: 24,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.folder_open, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'Grant Access to Pictures',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'To manage your photos (rename, move, delete), Relic needs access to your "Pictures" folder.\n\nPlease tap the button below and select the "Pictures" folder.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_currentUri != null)
              Column(
                children: [
                  const Text(
                    'Access Granted ✅',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Root: $_currentUri',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF37121),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text('Continue'),
                  ),
                  TextButton(
                    onPressed: _requestPermission,
                    child: const Text('Change Folder'),
                  ),
                ],
              )
            else
              ElevatedButton(
                onPressed: _requestPermission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF37121),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Text('Select "Pictures" Folder'),
              ),
          ],
        ),
      ),
    );
  }
}
