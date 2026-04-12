import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import 'vault_screen.dart';

class VaultAuthScreen extends StatefulWidget {
  const VaultAuthScreen({super.key});

  @override
  State<VaultAuthScreen> createState() => _VaultAuthScreenState();
}

class _VaultAuthScreenState extends State<VaultAuthScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _pinController = TextEditingController();
  bool _isPinSet = false;
  bool _isSettingUp = false;
  String _setupStep = ''; // 'create', 'confirm'
  String _firstPin = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final isSet = await _authService.isPinSet();
    setState(() {
      _isPinSet = isSet;
      if (!isSet) {
        _isSettingUp = true;
        _setupStep = 'create';
      } else {
        _authenticateBiometric();
      }
    });
  }

  Future<void> _authenticateBiometric() async {
    _authService.isAuthenticating = true;
    try {
      final authenticated = await _authService.authenticateWithBiometrics();
      if (authenticated) {
        _navigateToVault();
      }
    } finally {
      _authService.isAuthenticating = false;
    }
  }

  void _handlePinInput(String value) {
    if (_pinController.text.length < 4) {
      setState(() {
        _pinController.text += value;
        _errorMessage = '';
      });
    }

    if (_pinController.text.length == 4) {
      _submitPin();
    }
  }

  void _deleteDigit() {
    if (_pinController.text.isNotEmpty) {
      setState(() {
        _pinController.text = _pinController.text.substring(
          0,
          _pinController.text.length - 1,
        );
        _errorMessage = '';
      });
    }
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text;
    _pinController.clear();

    if (_isSettingUp) {
      if (_setupStep == 'create') {
        setState(() {
          _firstPin = pin;
          _setupStep = 'confirm';
        });
      } else if (_setupStep == 'confirm') {
        if (pin == _firstPin) {
          await _authService.setPin(pin);
          _navigateToVault();
        } else {
          setState(() {
            _errorMessage = 'PINs do not match. Try again.';
            _setupStep = 'create';
            _firstPin = '';
          });
        }
      }
    } else {
      final isValid = await _authService.verifyPin(pin);
      if (isValid) {
        _navigateToVault();
      } else {
        setState(() {
          _errorMessage = 'Incorrect PIN';
        });
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _navigateToVault() {
    _authService.isInVault = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const VaultScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            const Icon(Icons.lock_outline, size: 60, color: Color(0xFF6B3E26)),
            const SizedBox(height: 20),
            Text(
              _isSettingUp
                  ? (_setupStep == 'create'
                        ? 'Create Vault PIN'
                        : 'Confirm PIN')
                  : 'Enter Vault PIN',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B3E26),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 20,
              child: Text(
                _errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ),
            const SizedBox(height: 30),
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index < _pinController.text.length
                        ? const Color(0xFFF37121)
                        : Colors.grey[300],
                  ),
                );
              }),
            ),
            const Spacer(),
            // Numpad
            Container(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  _buildRow(['4', '5', '6']),
                  _buildRow(['7', '8', '9']),
                  _buildRow([_isPinSet ? 'bio' : '', '0', 'back']),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((key) {
          if (key.isEmpty) return const SizedBox(width: 80, height: 80);
          if (key == 'back') {
            return _buildNumpadButton(
              child: const Icon(Icons.backspace_outlined, size: 28),
              onTap: _deleteDigit,
            );
          }
          if (key == 'bio') {
            return _buildNumpadButton(
              child: const Icon(
                Icons.fingerprint,
                size: 32,
                color: Color(0xFFF37121),
              ),
              onTap: _authenticateBiometric,
            );
          }
          return _buildNumpadButton(
            child: Text(
              key,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
            ),
            onTap: () => _handlePinInput(key),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNumpadButton({
    required Widget child,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
