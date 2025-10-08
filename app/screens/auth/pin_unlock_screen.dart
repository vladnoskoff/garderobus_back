import 'package:flutter/material.dart';
import '../../services/api_service.dart';

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
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
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
