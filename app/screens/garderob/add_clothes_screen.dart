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
  final List<File> _itemImages = [];
  final List<File> _labelImages = [];
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

  Future<void> _addImageFromCamera({required bool forLabels}) async {
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
          final target = forLabels ? _labelImages : _itemImages;
          target.insert(0, file);
        });
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

  Future<void> _addImagesFromGallery({required bool forLabels}) async {
    final granted = await _ensureGalleryPermission();
    if (!granted) return;
    try {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles == null || pickedFiles.isEmpty) {
        return;
      }
      final target = forLabels ? _labelImages : _itemImages;
      final existingPaths = target.map((file) => file.path).toSet();
      final newFiles = pickedFiles
          .map((picked) => File(picked.path))
          .where((file) => !existingPaths.contains(file.path))
          .toList(growable: false);
      if (newFiles.isEmpty) {
        return;
      }
      setState(() {
        target.addAll(newFiles);
      });
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

  void _removeImage({required bool forLabels, required int index}) {
    final target = forLabels ? _labelImages : _itemImages;
    if (index < 0 || index >= target.length) return;
    setState(() {
      target.removeAt(index);
    });
  }

  void _setAsPrimary(int index) {
    if (index <= 0 || index >= _itemImages.length) return;
    setState(() {
      final file = _itemImages.removeAt(index);
      _itemImages.insert(0, file);
    });
  }

  Future<void> _showAddImageOptions({required bool forLabels}) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
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
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Сделать фото'),
                  onTap: () {
                    Navigator.pop(context);
                    if (_isLoading) return;
                    _addImageFromCamera(forLabels: forLabels);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Выбрать из галереи'),
                  onTap: () {
                    Navigator.pop(context);
                    if (_isLoading) return;
                    _addImagesFromGallery(forLabels: forLabels);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageCard({
    required File image,
    required bool forLabels,
    required int index,
    required ColorScheme colorScheme,
    VoidCallback? onSetPrimary,
  }) {
    final isPrimary = onSetPrimary != null && index == 0;

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.file(
              image,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.surface.withOpacity(0.8),
            child: IconButton(
              iconSize: 18,
              padding: EdgeInsets.zero,
              onPressed: _isLoading
                  ? null
                  : () => _removeImage(forLabels: forLabels, index: index),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ),
        if (onSetPrimary != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: FilterChip(
              selected: isPrimary,
              label: Text(isPrimary ? 'Главное' : 'Сделать главным'),
              avatar: Icon(
                isPrimary ? Icons.star : Icons.star_border,
                color:
                    isPrimary ? colorScheme.onPrimaryContainer : colorScheme.primary,
              ),
              onSelected: _isLoading || isPrimary ? null : (_) => onSetPrimary(),
            ),
          ),
      ],
    );
  }

  Widget _buildImageGrid({
    required String title,
    required String description,
    required List<File> images,
    required bool forLabels,
    required ColorScheme colorScheme,
    void Function()? onAdd,
    VoidCallback? onAddPressed,
    void Function(int index)? onSetPrimary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style:
              Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(0.8)),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final itemWidth = (width - 12) / 2;
            final children = <Widget>[
              ...List.generate(images.length, (index) {
                return SizedBox(
                  width: itemWidth,
                  child: _buildImageCard(
                    image: images[index],
                    forLabels: forLabels,
                    index: index,
                    colorScheme: colorScheme,
                    onSetPrimary:
                        onSetPrimary == null ? null : () => onSetPrimary(index),
                  ),
                );
              }),
              SizedBox(
                width: itemWidth,
                child: _buildAddTile(colorScheme: colorScheme, onTap: onAdd ?? onAddPressed),
              ),
            ];

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: children,
            );
          },
        ),
      ],
    );
  }

  Widget _buildAddTile({
    required ColorScheme colorScheme,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
          color: colorScheme.surfaceVariant.withOpacity(0.4),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_outlined, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: 8),
              const Text('Добавить'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      validator: validator,
    );
  }

  Future<void> submit() async {
    if (!_useAiAutoFill && !_formKey.currentState!.validate()) {
      return;
    }

    if (_itemImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одно изображение')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final combinedImages = <File>[..._itemImages, ..._labelImages];
      final bool hasLabels = _labelImages.isNotEmpty;
      final int? labelImageIndex = hasLabels ? _itemImages.length + 1 : null;

      final bool shouldSplitIntoPairs =
          _itemImages.length > 1 && _itemImages.length == _labelImages.length;
      final bool splitIntoItems = shouldSplitIntoPairs;
      final int? imagesPerItem = shouldSplitIntoPairs ? 2 : null;
      final int? groupLabelIndex = shouldSplitIntoPairs ? 2 : labelImageIndex;

      final isOnline = await NetworkService.isConnected();
      await ApiService.addClothes(
        name: _useAiAutoFill ? '' : _nameController.text.trim(),
        category: _useAiAutoFill ? '' : _categoryController.text.trim(),
        season: _useAiAutoFill ? '' : season,
        color: _useAiAutoFill ? '' : _colorController.text.trim(),
        material: _materialController.text.trim().isEmpty
            ? null
            : _materialController.text.trim(),
        images: combinedImages,
        autoFill: _useAiAutoFill,
        locationId: _selectedLocationId,
        splitIntoItems: splitIntoItems,
        imagesPerItem: imagesPerItem,
        labelImageIndex: groupLabelIndex,
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
                        color: colorScheme.surfaceVariant.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 26,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(Icons.style_outlined, color: colorScheme.primary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Заполните карточку вещи',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Загрузите фото, и мы попробуем определить название, категорию и цвет автоматически.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              ChoiceChip(
                                label: const Text('Заполнить самостоятельно'),
                                selected: !_useAiAutoFill,
                                onSelected: _isLoading
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          _useAiAutoFill = !selected;
                                        });
                                      },
                              ),
                              ChoiceChip(
                                label: const Text('Использовать заполнение ИИ'),
                                selected: _useAiAutoFill,
                                onSelected: _isLoading
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          _useAiAutoFill = selected;
                                        });
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (_isLocationsLoading)
                            const LinearProgressIndicator(minHeight: 4)
                          else if (_locations.isNotEmpty)
                            DropdownButtonFormField<int?>(
                              value: _selectedLocationId,
                              decoration: InputDecoration(
                                labelText: 'Локация гардероба',
                                filled: true,
                                fillColor: colorScheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(18),
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
                            )
                          else
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
                          const SizedBox(height: 18),
                          if (!_useAiAutoFill) ...[
                            _buildTextField(
                              controller: _nameController,
                              label: 'Название',
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Введите название' : null,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _categoryController,
                              label: 'Категория',
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Введите категорию' : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: season.isNotEmpty ? season : null,
                              decoration: InputDecoration(
                                labelText: 'Сезон',
                                filled: true,
                                fillColor: colorScheme.surface,
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
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _colorController,
                              label: 'Цвет',
                              validator: (value) =>
                                  value == null || value.trim().isEmpty ? 'Введите цвет' : null,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              controller: _materialController,
                              label: 'Материал (необязательно)',
                              validator: null,
                            ),
                            const SizedBox(height: 10),
                          ],
                          const SizedBox(height: 6),
                          _buildImageGrid(
                            title: 'Фотографии вещи',
                            description: 'Добавьте основной вид, спину или другие ракурсы.',
                            images: _itemImages,
                            forLabels: false,
                            colorScheme: colorScheme,
                            onAdd: _isLoading
                                ? null
                                : () => _showAddImageOptions(forLabels: false),
                            onSetPrimary: (index) => _setAsPrimary(index),
                          ),
                          const SizedBox(height: 18),
                          _buildImageGrid(
                            title: 'Фотографии бирок',
                            description: 'Прикрепите бирку или информацию по уходу за вещью.',
                            images: _labelImages,
                            forLabels: true,
                            colorScheme: colorScheme,
                            onAdd: _isLoading
                                ? null
                                : () => _showAddImageOptions(forLabels: true),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Первое фото станет главным для вещи. При парной загрузке (фото + бирка) одинаковым количеством снимков мы создадим отдельную вещь на каждую пару.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _isLoading ? null : submit,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
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
 
