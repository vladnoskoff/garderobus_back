import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../services/api_service.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final TextEditingController _newPinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  bool _hasPin = false;
  int? _userId;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  void dispose() {
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });
    try {
      final idString = await _storage.read(key: 'user_id');
      final parsedId = idString != null ? int.tryParse(idString) : null;
      bool hasPin = false;
      if (parsedId != null) {
        try {
          final user = await ApiService.getUser(parsedId);
          hasPin = user['has_pin'] == true;
        } catch (_) {
          hasPin = await ApiService.loadCachedHasPin();
        }
      }
      if (!mounted) return;
      setState(() {
        _userId = parsedId;
        _hasPin = hasPin;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить данные: $e';
        _isLoading = false;
      });
    }
  }

  String? _validatePin(String value) {
    if (value.length < 4 || value.length > 8) {
      return 'PIN-код должен содержать от 4 до 8 цифр';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Используйте только цифры';
    }
    return null;
  }

  Future<void> _savePin() async {
    final newPin = _newPinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    final validationError = _validatePin(newPin);
    if (validationError != null) {
      setState(() {
        _error = validationError;
        _successMessage = null;
      });
      return;
    }

    if (newPin != confirmPin) {
      setState(() {
        _error = 'PIN-коды не совпадают';
        _successMessage = null;
      });
      return;
    }

    if (_userId == null) {
      setState(() {
        _error = 'Пользователь не найден';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await ApiService.setPinCode(_userId!, newPin);
      if (!mounted) return;
      setState(() {
        _hasPin = true;
        _successMessage = 'PIN-код сохранён';
        _newPinController.clear();
        _confirmPinController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось сохранить PIN-код: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _removePin() async {
    if (_userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить PIN-код'),
        content: const Text('Вы уверены, что хотите отключить PIN-код?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      await ApiService.clearPinCode(_userId!);
      if (!mounted) return;
      setState(() {
        _hasPin = false;
        _successMessage = 'PIN-код удалён';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось удалить PIN-код: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN-код'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasPin
                        ? 'PIN-код уже установлен. Вы можете изменить его или отключить защиту.'
                        : 'Установите PIN-код для быстрой защиты приложения.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _newPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Новый PIN-код',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Подтвердите PIN-код',
                      counterText: '',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _savePin,
                    icon: const Icon(Icons.save),
                    label: const Text('Сохранить'),
                  ),
                  const SizedBox(height: 12),
                  if (_hasPin)
                    OutlinedButton.icon(
                      onPressed: _isLoading ? null : _removePin,
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Отключить PIN-код'),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    ),
                  ],
                  if (_successMessage != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _successMessage!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
