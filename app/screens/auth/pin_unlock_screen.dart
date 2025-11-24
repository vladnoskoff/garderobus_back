import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/biometric_auth_service.dart';
import '../../l10n/l10n_extensions.dart';

class PinUnlockScreen extends StatefulWidget {
  final int userId;
  final String? accessToken;
  final Future<void> Function(BuildContext context) onUnlocked;
  final Future<void> Function(BuildContext context)? onCancel;

  const PinUnlockScreen({
    super.key,
    required this.userId,
    this.accessToken,
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
      setState(() => _error = context.l10n.authPinLengthError);
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final isValid =
          await ApiService.verifyPin(widget.userId, pin, accessToken: widget.accessToken);
      if (!mounted) return;

      if (isValid) {
        _pinController.clear();
        await widget.onUnlocked(context);
      } else {
        setState(() {
          _error = context.l10n.authPinInvalid;
        });
      }
    } catch (e) {
      if (!mounted) return;
      final rawMessage = e.toString();
      final cleanedMessage =
          rawMessage.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      setState(() {
        _error = cleanedMessage.isNotEmpty
            ? context.l10n.authPinVerifyError(cleanedMessage)
            : context.l10n.authPinVerifyGeneric;
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
      reason: context.l10n.authBiometricReason,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isBiometricAuthenticating = false;
      });
      await widget.onUnlocked(context);
    } else {
      setState(() {
        _error = context.l10n.authBiometricFailed;
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
                context.l10n.authPinPrompt,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.authPinHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Semantics(
                label: context.l10n.authPinLabel,
                hint: context.l10n.authPinHint,
                textField: true,
                child: TextField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: context.l10n.authPinLabel,
                    counterText: '',
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _verifyPin(),
                ),
              ),
              const SizedBox(height: 20),
              Semantics(
                button: true,
                enabled: !_isVerifying,
                label: context.l10n.authUnlockAction,
                child: FilledButton(
                  onPressed: _isVerifying ? null : _verifyPin,
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.authUnlockAction),
                ),
              ),
              if (_isBiometricAuthenticating) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
              if (widget.onCancel != null)
                Semantics(
                  button: true,
                  label: context.l10n.authExitAction,
                  child: TextButton(
                    onPressed: () async {
                      await widget.onCancel!(context);
                    },
                    child: Text(context.l10n.authExitAction),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
