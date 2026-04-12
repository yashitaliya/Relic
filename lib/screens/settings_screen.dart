import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:ui';
import '../services/settings_service.dart';
import '../services/saf_service.dart';
import '../widgets/custom_notification.dart';
import '../widgets/selection_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  int _gridSize = 3;
  int _startPage = 0;
  bool _isAppLockEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final gridSize = await _settingsService.getGridSize();
    final startPage = await _settingsService.getStartPage();
    final appLock = await _settingsService.getAppLockEnabled();
    setState(() {
      _gridSize = gridSize;
      _startPage = startPage;
      _isAppLockEnabled = appLock;
    });
  }

  Future<void> _changeGridSize(int newSize) async {
    await _settingsService.setGridSize(newSize);
    setState(() {
      _gridSize = newSize;
    });
  }

  Future<void> _changeStartPage(int newPage) async {
    await _settingsService.setStartPage(newPage);
    setState(() {
      _startPage = newPage;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        if (mounted) {
          CustomNotification.show(
            context,
            message: 'Device authentication not supported',
            type: NotificationType.error,
          );
        }
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason:
            'Authenticate to ${value ? 'enable' : 'disable'} App Lock',
        options: const AuthenticationOptions(stickyAuth: true),
      );

      if (didAuthenticate) {
        if (!mounted) return;
        await _settingsService.setAppLockEnabled(value);
        setState(() => _isAppLockEnabled = value);
      }
    } catch (e) {
      if (mounted) {
        CustomNotification.show(
          context,
          message: 'Authentication error: $e',
          type: NotificationType.error,
        );
      }
    }
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
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color(0xFF6B3E26),
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Settings',
                          style: TextStyle(
                            color: Color(0xFF6B3E26),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
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
      body: ListView(
        padding: EdgeInsets.only(
          top: 110 + MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        children: [
          _buildSection(
            title: 'General',
            children: [
              _buildSettingTile(
                icon: Icons.home,
                title: 'Start Page',
                subtitle: _startPage == 0 ? 'Home' : 'Albums',
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  SelectionSheet.show(
                    context,
                    title: 'Start Page',
                    options: ['Home', 'Albums'],
                    selectedValue: _startPage == 0 ? 'Home' : 'Albums',
                    onSelected: (value) {
                      _changeStartPage(value == 'Home' ? 0 : 2);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Security',
            children: [
              _buildSettingTile(
                icon: Icons.lock,
                title: 'App Lock',
                subtitle: 'Use system password/biometrics',
                trailing: Switch(
                  value: _isAppLockEnabled,
                  activeThumbColor: const Color(0xFFF37121),
                  onChanged: _toggleAppLock,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Display',
            children: [
              _buildSettingTile(
                icon: Icons.grid_view,
                title: 'Grid Size',
                subtitle: '$_gridSize columns',
                trailing: const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
                onTap: () {
                  SelectionSheet.show(
                    context,
                    title: 'Grid Size',
                    options: ['2', '3', '4', '5'],
                    selectedValue: _gridSize.toString(),
                    onSelected: (value) {
                      _changeGridSize(int.parse(value));
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Storage',
            children: [
              _buildSettingTile(
                icon: Icons.cleaning_services,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: () async {
                  try {
                    await _settingsService.clearCache();
                    if (!context.mounted) return;
                    CustomNotification.show(
                      context,
                      message: 'Cache cleared successfully',
                      type: NotificationType.success,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    CustomNotification.show(
                      context,
                      message: 'Failed to clear cache',
                      type: NotificationType.error,
                    );
                  }
                },
                trailing: ElevatedButton(
                  onPressed: () async {
                    try {
                      await _settingsService.clearCache();
                      if (!context.mounted) return;
                      CustomNotification.show(
                        context,
                        message: 'Cache cleared successfully',
                        type: NotificationType.success,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      CustomNotification.show(
                        context,
                        message: 'Failed to clear cache',
                        type: NotificationType.error,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF37121),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(height: 16),
              const SizedBox(height: 16),
              FutureBuilder<bool>(
                future: SafService().hasAllFilesAccess(),
                builder: (context, snapshot) {
                  final hasAccess = snapshot.data ?? false;
                  return _buildSettingTile(
                    icon: Icons.sd_storage,
                    title: 'All Files Access',
                    subtitle: hasAccess
                        ? 'Granted'
                        : 'Grant for better experience',
                    trailing: hasAccess
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : ElevatedButton(
                            onPressed: () async {
                              await SafService().requestAllFilesAccess();
                              // Wait a bit for user to return
                              await Future.delayed(const Duration(seconds: 1));
                              setState(() {}); // Refresh UI
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF37121),
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Grant'),
                          ),
                    onTap: hasAccess
                        ? null
                        : () async {
                            await SafService().requestAllFilesAccess();
                            setState(() {});
                          },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'About',
            children: [
              _buildSettingTile(
                icon: Icons.info_outline,
                title: 'About Relic',
                subtitle: 'Version 0.1.0',
                onTap: _showAboutDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B3E26),
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF37121).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFFF37121), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (onTap != null && trailing == null)
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Relic'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Relic Gallery App'),
            SizedBox(height: 8),
            Text('Version 0.1.0'),
            SizedBox(height: 16),
            Text(
              'A modern photo gallery app designed to manage and view your precious memories.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFFF37121)),
            ),
          ),
        ],
      ),
    );
  }
}
