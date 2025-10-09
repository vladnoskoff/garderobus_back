import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/biometric_auth_service.dart';

class PinUnlockScreen extends StatefulWidget {
  final int userId;
  final VoidCallback onUnlocked;
  final VoidCallback? onCancel;

  const PinUnlockScreen({
    super.key,
    required this.userId,
    required this.onUnlocked,
    this.onCancel,
  });

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isVerifying = false;
  bool _isBiometricAuthenticating = false;
  bool _canUseBiometrics = false;
  bool _hasAttemptedBiometric = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBiometricSupport();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricSupport() async {
    final support = await BiometricAuthService.checkSupport();
    if (!mounted || !support.canAuthenticate) return;

    setState(() {
      _canUseBiometrics = true;
    });

    _attemptBiometricUnlock();
  }

  void _attemptBiometricUnlock() {
    if (!_canUseBiometrics || _hasAttemptedBiometric || _isBiometricAuthenticating) {
      return;
    }

    _hasAttemptedBiometric = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _unlockWithBiometrics();
    });
  }

  Future<void> _verifyPin() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4 || pin.length > 8 || !RegExp(r'^[0-9]+$').hasMatch(pin)) {
      setState(() => _error = 'Введите PIN-код из 4–8 цифр.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final isValid = await ApiService.verifyPin(widget.userId, pin);
      if (!mounted) return;

      if (isValid) {
        _pinController.clear();
        widget.onUnlocked();
      } else {
        setState(() {
          _error = 'Неверный PIN-код. Попробуйте ещё раз.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось проверить PIN-код: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (!mounted) return;
    setState(() {
      _isBiometricAuthenticating = true;
      _error = null;
    });

    final success = await BiometricAuthService.authenticate(
      reason: 'Подтвердите личность для доступа к гардеробу',
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isBiometricAuthenticating = false;
      });
      widget.onUnlocked();
    } else {
      setState(() {
        _error =
            'Биометрическая аутентификация не выполнена. Введите PIN-код.';
        _isBiometricAuthenticating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Введите PIN-код',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Для продолжения требуется подтверждение безопасности.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 8,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  labelText: 'PIN-код',
                  counterText: '',
                  errorText: _error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _verifyPin(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _isVerifying ? null : _verifyPin,
                child: _isVerifying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Разблокировать'),
              ),
              if (_isBiometricAuthenticating) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
              if (widget.onCancel != null)
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Выйти'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
