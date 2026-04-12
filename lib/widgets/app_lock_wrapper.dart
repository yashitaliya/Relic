import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;
  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper>
    with WidgetsBindingObserver {
  final SettingsService _settingsService = SettingsService();
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isLocked = false;
  bool _isAuthenticating = false;
  DateTime? _lastAuthTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLock();
    }
  }

  Future<void> _checkLock() async {
    if (_isLocked) return;

    // Don't lock if internal authentication (like Vault) is in progress
    if (AuthService().isAuthenticating) return;

    // Don't lock if user is currently in vault
    if (AuthService().isInVault) return;

    final enabled = await _settingsService.getAppLockEnabled();
    if (!enabled) return;

    // Prevent loop if just authenticated (within 2 seconds)
    if (_lastAuthTime != null &&
        DateTime.now().difference(_lastAuthTime!) <
            const Duration(seconds: 2)) {
      return;
    }

    if (!_isAuthenticating) {
      setState(() {
        _isLocked = true;
      });
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();

      if (!canAuthenticate) {
        // Fallback or disable lock if not supported
        setState(() {
          _isLocked = false;
        });
        _isAuthenticating = false;
        return;
      }

      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Unlock Relic Gallery',
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        _lastAuthTime = DateTime.now();
        setState(() {
          _isLocked = false;
        });
      }
    } catch (e) {
      // Handle error, maybe retry
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isLocked)
          Scaffold(
            backgroundColor: const Color(0xFFFAFAFA),
            body: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5EC),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFF37121,
                            ).withValues(alpha: 0.12),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.lock,
                        size: 64,
                        color: Color(0xFFF37121),
                      ),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Relic Gallery Locked',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B3E26),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Authenticate to unlock',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _authenticate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF37121),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Unlock',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
