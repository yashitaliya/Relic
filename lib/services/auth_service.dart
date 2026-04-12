import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _pinKey = 'vault_pin';
  bool isAuthenticating = false;
  bool isInVault = false; // Track if user is currently in vault

  // Check if device supports biometrics
  Future<bool> get isBiometricAvailable async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
      return canAuthenticate;
    } on PlatformException catch (e) {
      debugPrint('Error checking biometrics: $e');
      return false;
    }
  }

  // Authenticate with Biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final isAvailable = await isBiometricAvailable;
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: 'Scan your fingerprint or face to access the Vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  // Set PIN
  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  // Verify PIN
  Future<bool> verifyPin(String pin) async {
    final storedPin = await _storage.read(key: _pinKey);
    return storedPin == pin;
  }

  // Check if PIN is set
  Future<bool> isPinSet() async {
    final pin = await _storage.read(key: _pinKey);
    return pin != null;
  }

  // Remove PIN (for reset)
  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
  }
}
