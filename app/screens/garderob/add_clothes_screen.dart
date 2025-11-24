import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import '../../services/network_service.dart';
import '../../services/sync_service.dart';
import '../../widgets/rounded_back_button.dart';

enum _PhotoPermissionAction {
  keepLimited,
  chooseMore,
  openSettings,
}

class AddClothesScreen extends StatefulWidget {
  final int? initialLocationId;

  const AddClothesScreen({super.key, this.initialLocationId});

  @override
  _AddClothesScreenState createState() => _AddClothesScreenState();
}

class _AddClothesScreenState extends State<AddClothesScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _materialController = TextEditingController();
  String season = '';
  final List<File> _images = [];
  late final PageController _imagePageController;
  int _currentImageIndex = 0;
  bool _isLoading = false;
  bool _useAiAutoFill = true;
  int? _selectedLocationId;
  List<dynamic> _locations = [];
  bool _isLocationsLoading = false;

  final picker = ImagePicker();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();
    _loadUserIdAndLocations();
  }

  Future<void> _loadUserIdAndLocations() async {
    setState(() => _isLocationsLoading = true);
    try {
      final idString = await _storage.read(key: 'user_id');
      if (idString == null) return;
      final parsedId = int.tryParse(idString);
      if (parsedId == null) return;
      final locations = await ApiService.getWardrobeLocations(parsedId);
      final storedLocationIdString = await _storage.read(key: 'selected_location_id');
      final storedLocationId = storedLocationIdString != null
          ? int.tryParse(storedLocationIdString)
          : null;
      int? initialLocationId = widget.initialLocationId ?? storedLocationId;
      if (initialLocationId != null) {
        final exists = locations.any((loc) {
          if (loc is! Map<String, dynamic>) return false;
          return _parseLocationId(loc['id']) == initialLocationId;
        });
        if (!exists) {
          initialLocationId = null;
        }
      }
      setState(() {
        _locations = locations;
        _selectedLocationId = initialLocationId;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить локации: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLocationsLoading = false);
      }
    }
  }




  Future<bool> _requestPermission(Permission permission) async {
    var status = await permission.status;

    if (status.isGranted) {
      return true;
    }

    if (status.isLimited && permission == Permission.photos) {
      return await _handleLimitedPhotoPermission(permission);
    }

    status = await permission.request();

    if (status.isGranted) {
      return true;
    }

    if (status.isLimited && permission == Permission.photos) {
      return await _handleLimitedPhotoPermission(permission);
    }

    if (mounted) {
      if (status.isPermanentlyDenied || status.isRestricted) {
        _showPermissionSettingsSnackBar(permission);
      } else if (status.isDenied) {
        _showPermissionRationaleSnackBar(permission);
      }
    }

    return false;
  }

  void _showPermissionRationaleSnackBar(Permission permission) {
    final description = permission == Permission.camera
        ? 'Камера недоступна без разрешения.'
        : 'Чтобы выбрать фото, разрешите доступ к библиотеке.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(description)),
    );
  }

  void _showPermissionSettingsSnackBar(Permission permission) {
    final description = permission == Permission.camera
        ? 'Разрешите доступ к камере через настройки приложения'
        : 'Разрешите доступ к Фото через настройки приложения';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(description),
        action: SnackBarAction(
          label: 'Настройки',
          onPressed: () => openAppSettings(),
        ),
      ),
    );
  }

  Future<bool> _handleLimitedPhotoPermission(Permission permission) async {
    if (!mounted) return false;

    final action = await showModalBottomSheet<_PhotoPermissionAction>(
      context: context,
      useRootNavigator: true,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'У вас включен частичный доступ к Фото',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  'Вы можете продолжить с выбранными изображениями или разрешить '
                  'приложению доступ ко всем фото.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle, color: colorScheme.primary),
                  title: const Text('Продолжить с текущим доступом'),
                  onTap: () => Navigator.pop(context, _PhotoPermissionAction.keepLimited),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.collections, color: colorScheme.primary),
                  title: const Text('Выбрать другие фотографии'),
                  subtitle: const Text('Откроется системный диалог с выбором доступа'),
                  onTap: () => Navigator.pop(context, _PhotoPermissionAction.chooseMore),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings, color: colorScheme.primary),
                  title: const Text('Настроить через настройки iOS'),
                  subtitle: const Text('Можно дать полный доступ ко всем фото'),
                  onTap: () => Navigator.pop(context, _PhotoPermissionAction.openSettings),
                ),
              ],
            ),
          ),
        );
      },
    );

    switch (action) {
      case _PhotoPermissionAction.chooseMore:
        final updatedStatus = await permission.request();
        if (updatedStatus.isGranted || updatedStatus.isLimited) {
          return true;
        }
        if (mounted &&
            (updatedStatus.isPermanentlyDenied || updatedStatus.isRestricted)) {
          _showPermissionSettingsSnackBar(permission);
        }
        return false;
      case _PhotoPermissionAction.openSettings:
        await openAppSettings();
        return false;
      case _PhotoPermissionAction.keepLimited:
      case null:
        return true;
    }
  }

Future<void> _addImageFromCamera() async {
  final granted = await _requestPermission(Permission.camera);
  if (!granted) return;
  try {
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() {
        _images.insert(0, file);
        _currentImageIndex = 0;
      });
      if (_imagePageController.hasClients) {
        _imagePageController.jumpToPage(0);
      }
    }
  } on PlatformException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось открыть камеру: ${e.message ?? e.code}')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ошибка при создании фото: $e')),
    );
  }
}

Future<bool> _ensureGalleryPermission() async {
  if (Platform.isIOS) {
    return await _requestPermission(Permission.photos);
  }
  final storageGranted = await _requestPermission(Permission.storage);
  if (storageGranted) return true;
  return await _requestPermission(Permission.photos);
}

Future<void> _addImagesFromGallery() async {
  final granted = await _ensureGalleryPermission();
  if (!granted) return;
  try {
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles == null || pickedFiles.isEmpty) {
      return;
    }
    final existingPaths = _images.map((file) => file.path).toSet();
    final newFiles = pickedFiles
        .map((picked) => File(picked.path))
        .where((file) => !existingPaths.contains(file.path))
        .toList(growable: false);
    if (newFiles.isEmpty) {
      return;
    }
    setState(() {
      _images.addAll(newFiles);
      _currentImageIndex = _images.length - newFiles.length;
    });
    if (_imagePageController.hasClients) {
      _imagePageController.jumpToPage(_currentImageIndex);
    }
  } on PlatformException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Не удалось открыть галерею: ${e.message ?? e.code}')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Ошибка при выборе изображений: $e')),
    );
  }
}

void _removeImage(int index) {
  if (index < 0 || index >= _images.length) return;
  setState(() {
    _images.removeAt(index);
    if (_images.isEmpty) {
      _currentImageIndex = 0;
    } else if (_currentImageIndex >= _images.length) {
      _currentImageIndex = _images.length - 1;
    }
  });
  if (_imagePageController.hasClients && _images.isNotEmpty) {
    _imagePageController.jumpToPage(_currentImageIndex);
  }
}

void _setAsPrimary(int index) {
  if (index <= 0 || index >= _images.length) return;
  setState(() {
    final file = _images.removeAt(index);
    _images.insert(0, file);
    _currentImageIndex = 0;
  });
  if (_imagePageController.hasClients) {
    _imagePageController.jumpToPage(0);
  }
}

Widget _buildImagesPreview(ColorScheme colorScheme) {
  if (_images.isEmpty) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Text('Добавьте хотя бы одно фото одежды'),
    );
  }

  return SizedBox(
    height: 260,
    child: Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: PageView.builder(
            controller: _imagePageController,
            onPageChanged: (index) {
              setState(() {
                _currentImageIndex = index;
              });
            },
            itemCount: _images.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                ),
                child: Image.file(
                  _images[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              );
            },
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surface.withOpacity(0.7),
            ),
            onPressed: _isLoading ? null : () => _removeImage(_currentImageIndex),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Удалить фото',
          ),
        ),
        if (_images.length > 1 && _currentImageIndex != 0)
          Positioned(
            top: 12,
            left: 12,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _setAsPrimary(_currentImageIndex),
              icon: const Icon(Icons.star),
              label: const Text('Главное фото'),
            ),
          ),
        if (_images.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_images.length, (index) {
                final bool isActive = index == _currentImageIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isActive ? 14 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    ),
  );
}

  Future<void> submit() async {
    if (!_useAiAutoFill && !_formKey.currentState!.validate()) {
      return;
    }

    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одно изображение')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final isOnline = await NetworkService.isConnected();
      await ApiService.addClothes(
        name: _useAiAutoFill ? '' : _nameController.text.trim(),
        category: _useAiAutoFill ? '' : _categoryController.text.trim(),
        season: _useAiAutoFill ? '' : season,
        color: _useAiAutoFill ? '' : _colorController.text.trim(),
        material: _materialController.text.trim().isEmpty
            ? null
            : _materialController.text.trim(),
        images: List<File>.from(_images),
        autoFill: _useAiAutoFill,
        locationId: _selectedLocationId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOnline
                ? 'Одежда добавлена'
                : 'Добавлено в офлайн. Синхронизируем при восстановлении сети',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка добавления одежды: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _colorController.dispose();
    _materialController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  int? _parseLocationId(dynamic rawId) {
    if (rawId is int) return rawId;
    if (rawId is String) {
      return int.tryParse(rawId);
    }
    if (rawId != null) {
      return int.tryParse(rawId.toString());
    }
    return null;
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    final locationItems = _locations
        .whereType<Map<String, dynamic>>()
        .map((loc) {
          final parsedId = _parseLocationId(loc['id']);
          if (parsedId == null) {
            return null;
          }
          final name = loc['name']?.toString().trim();
          return DropdownMenuItem<int?>(
            value: parsedId,
            child: Text(name?.isNotEmpty == true ? name! : 'Локация #$parsedId'),
          );
        })
        .whereType<DropdownMenuItem<int?>>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        leading: const RoundedBackButton(),
        centerTitle: true,
        title: const Text('Добавить одежду'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final targetWidth = math.min(constraints.maxWidth, 820.0);
            final horizontalPadding = math.max(20.0, (constraints.maxWidth - targetWidth) / 2);

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  24,
                  horizontalPadding,
                  24 + paddingBottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primaryContainer
                                .withOpacity(theme.brightness == Brightness.dark ? 0.35 : 0.85),
                            colorScheme.surfaceVariant
                                .withOpacity(theme.brightness == Brightness.dark ? 0.3 : 0.7),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  color: colorScheme.onPrimaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Заполните карточку вещи и добавьте фото',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          DropdownButtonFormField<bool>(
                            value: _useAiAutoFill,
                            decoration: InputDecoration(
                              labelText: 'Заполнение данных',
                              border:
                                  OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                              filled: true,
                              fillColor: colorScheme.surface.withOpacity(
                                theme.brightness == Brightness.dark ? 0.35 : 0.9,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: false,
                                child: Text('Заполнить самостоятельно'),
                              ),
                              DropdownMenuItem(
                                value: true,
                                child: Text('Использовать заполнение ИИ'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _useAiAutoFill = value ?? false;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          if (_isLocationsLoading)
                            const LinearProgressIndicator()
                          else if (_locations.isNotEmpty)
                            DropdownButtonFormField<int?>(
                              value: _selectedLocationId,
                              decoration: InputDecoration(
                                labelText: 'Локация гардероба',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                filled: true,
                                fillColor: colorScheme.surface.withOpacity(
                                  theme.brightness == Brightness.dark ? 0.35 : 0.9,
                                ),
                              ),
                              items: [
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Без привязки'),
                                ),
                                ...locationItems,
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedLocationId = value;
                                });
                                if (value == null) {
                                  _storage.delete(key: 'selected_location_id');
                                } else {
                                  _storage.write(
                                    key: 'selected_location_id',
                                    value: value.toString(),
                                  );
                                }
                              },
                            ),
                          if (_locations.isEmpty && !_isLocationsLoading)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                color: colorScheme.surface.withOpacity(
                                  theme.brightness == Brightness.dark ? 0.25 : 0.85,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                'Добавьте локации гардероба в настройках, чтобы привязывать вещи.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          const SizedBox(height: 20),
                          if (_useAiAutoFill)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer.withOpacity(
                                  theme.brightness == Brightness.dark ? 0.35 : 0.7,
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Text(
                                'Загрузите фото, а мы попробуем определить название, категорию и цвет автоматически.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          if (!_useAiAutoFill) ...[
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Название',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Введите название';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _categoryController,
                              decoration: InputDecoration(
                                labelText: 'Категория',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Введите категорию';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              value: season.isNotEmpty ? season : null,
                              decoration: InputDecoration(
                                labelText: 'Сезон',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              items: const ['Весна', 'Лето', 'Осень', 'Зима']
                                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                  .toList(),
                              onChanged: (value) {
                                setState(() {
                                  season = value ?? '';
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Выберите сезон';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _colorController,
                              decoration: InputDecoration(
                                labelText: 'Цвет',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Введите цвет';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _materialController,
                              decoration: InputDecoration(
                                labelText: 'Материал (необязательно)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                          Text(
                            'Фотографии',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildImagesPreview(colorScheme),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: _isLoading ? null : _addImageFromCamera,
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('Камера'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: _isLoading ? null : _addImagesFromGallery,
                                icon: const Icon(Icons.image_outlined),
                                label: const Text('Галерея'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Первое фото станет главным. При необходимости переставьте порядок.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: _isLoading ? null : submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        colorScheme.onPrimary,
                                      ),
                                    ),
                                  )
                                : const Text('Добавить'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
 