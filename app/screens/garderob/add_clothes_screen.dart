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

class _ClothingDraft {
  _ClothingDraft();

  final List<File> garmentImages = [];
  final List<File> labelImages = [];
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
  final List<_ClothingDraft> _items = [
    _ClothingDraft(),
  ];
  bool _isMultipleItems = false;
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

  List<File>? _targetImages({required bool forLabels, required int itemIndex}) {
    if (itemIndex < 0 || itemIndex >= _items.length) return null;
    return forLabels ? _items[itemIndex].labelImages : _items[itemIndex].garmentImages;
  }

  bool _isLabelLimitReached(bool forLabels, List<File> target) {
    if (!forLabels) return false;
    if (target.length >= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Можно добавить только одну бирку на вещь')),
      );
      return true;
    }
    return false;
  }

  Future<void> _addImageFromCamera({
    required bool forLabels,
    required int itemIndex,
  }) async {
    final granted = await _requestPermission(Permission.camera);
    if (!granted) return;
    try {
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final target = _targetImages(forLabels: forLabels, itemIndex: itemIndex);
        if (target == null) return;
        if (_isLabelLimitReached(forLabels, target)) return;
        setState(() {
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

  Future<void> _addImagesFromGallery({
    required bool forLabels,
    required int itemIndex,
  }) async {
    final granted = await _ensureGalleryPermission();
    if (!granted) return;
    try {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles == null || pickedFiles.isEmpty) {
        return;
      }
      final target = _targetImages(forLabels: forLabels, itemIndex: itemIndex);
      if (target == null) return;
      if (_isLabelLimitReached(forLabels, target)) return;
      final existingPaths = target.map((file) => file.path).toSet();
      final newFiles = pickedFiles
          .map((picked) => File(picked.path))
          .where((file) => !existingPaths.contains(file.path))
          .toList(growable: false);
      if (newFiles.isEmpty) {
        return;
      }
      setState(() {
        target.addAll(newFiles.take(forLabels ? 1 - target.length : newFiles.length));
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

  void _removeImage({
    required bool forLabels,
    required int index,
    required int itemIndex,
  }) {
    final target = _targetImages(forLabels: forLabels, itemIndex: itemIndex);
    if (target == null) return;
    if (index < 0 || index >= target.length) return;
    setState(() {
      target.removeAt(index);
    });
  }

  void _setAsPrimary(int index, int itemIndex) {
    final target = _targetImages(forLabels: false, itemIndex: itemIndex);
    if (target == null) return;
    if (index <= 0 || index >= target.length) return;
    setState(() {
      final file = target.removeAt(index);
      target.insert(0, file);
    });
  }

  Future<void> _showAddImageOptions({
    required bool forLabels,
    required int itemIndex,
  }) async {
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
                    _addImageFromCamera(forLabels: forLabels, itemIndex: itemIndex);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image_outlined),
                  title: const Text('Выбрать из галереи'),
                  onTap: () {
                    Navigator.pop(context);
                    if (_isLoading) return;
                    _addImagesFromGallery(
                      forLabels: forLabels,
                      itemIndex: itemIndex,
                    );
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
    required int itemIndex,
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
                  : () => _removeImage(
                        forLabels: forLabels,
                        index: index,
                        itemIndex: itemIndex,
                      ),
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
    required int itemIndex,
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
                    itemIndex: itemIndex,
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

    try {
      final bool hasMultiple = _isMultipleItems;
      List<File> combinedImages;
      bool splitIntoItems = false;
      int? imagesPerItem;
      int? groupLabelIndex;

      if (hasMultiple) {
        if (_items.any((item) => item.garmentImages.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Добавьте фото для каждой вещи')),
          );
          return;
        }

        final firstItem = _items.first;
        final firstGarmentCount = firstItem.garmentImages.length;
        final hasLabels = firstItem.labelImages.isNotEmpty;
        final expectedTotal = firstGarmentCount + (hasLabels ? 1 : 0);

        final inconsistent = _items.any((item) {
          final labelMatches = hasLabels ? item.labelImages.isNotEmpty : item.labelImages.isEmpty;
          return item.garmentImages.length != firstGarmentCount ||
              !labelMatches ||
              (item.garmentImages.length + (hasLabels ? 1 : 0)) != expectedTotal;
        });

        if (inconsistent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Для пакетной загрузки количество фото (и наличие бирки) должно совпадать у каждой вещи.',
              ),
            ),
          );
          return;
        }

        combinedImages = _items
            .expand((item) => [
                  ...item.garmentImages,
                  if (hasLabels) item.labelImages.first,
                ])
            .toList();
        splitIntoItems = true;
        imagesPerItem = expectedTotal;
        groupLabelIndex = hasLabels ? firstGarmentCount + 1 : null;
      } else {
        final single = _items.first;
        combinedImages = [...single.garmentImages, ...single.labelImages];
        if (combinedImages.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Добавьте хотя бы одно изображение')),
          );
          return;
        }
        final bool hasLabels = single.labelImages.isNotEmpty;
        groupLabelIndex = hasLabels ? single.garmentImages.length + 1 : null;
      }

      setState(() {
        _isLoading = true;
      });

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
            final horizontalPadding =
                math.max(20.0, (constraints.maxWidth - targetWidth) / 2);

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  16,
                  horizontalPadding,
                  paddingBottom + 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModeToggle(colorScheme),
                    const SizedBox(height: 16),
                    _buildDetailsCard(theme, colorScheme, locationItems),
                    const SizedBox(height: 16),
                    if (_isMultipleItems)
                      _buildMultipleItemsSection(theme, colorScheme)
                    else
                      _buildSingleItemSection(theme, colorScheme),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildModeToggle(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              label: 'Одна вещь',
              selected: !_isMultipleItems,
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isMultipleItems = false;
                        if (_items.length > 1) {
                          _items.removeRange(1, _items.length);
                        }
                      });
                    },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModeButton(
              label: 'Несколько вещей',
              selected: _isMultipleItems,
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _isMultipleItems = true;
                      });
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsCard(
    ThemeData theme,
    ColorScheme colorScheme,
    List<DropdownMenuItem<int?>> locationItems,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
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
          if (!_useAiAutoFill) ...[
            const SizedBox(height: 18),
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
          ],
        ],
      ),
    );
  }

  Widget _buildSingleItemSection(ThemeData theme, ColorScheme colorScheme) {
    final item = _items.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface.withOpacity(0.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageGrid(
                title: 'Фотографии вещи',
                description: 'Добавьте основной вид, спину или другие ракурсы.',
                images: item.garmentImages,
                itemIndex: 0,
                forLabels: false,
                colorScheme: colorScheme,
                onAdd: _isLoading
                    ? null
                    : () => _showAddImageOptions(forLabels: false, itemIndex: 0),
                onSetPrimary: (index) => _setAsPrimary(index, 0),
              ),
              const SizedBox(height: 18),
              _buildImageGrid(
                title: 'Фотографии бирок',
                description: 'Прикрепите бирку или информацию по уходу за вещью.',
                images: item.labelImages,
                itemIndex: 0,
                forLabels: true,
                colorScheme: colorScheme,
                onAdd: _isLoading
                    ? null
                    : () => _showAddImageOptions(forLabels: true, itemIndex: 0),
              ),
              const SizedBox(height: 12),
              Text(
                'Первое фото станет главным. Бирку можно добавить отдельным фото.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
    );
  }

  Widget _buildMultipleItemsSection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        ...List.generate(_items.length, (index) {
          final item = _items[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index == _items.length - 1 ? 12 : 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Вещь ${index + 1}',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      if (_items.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _items.removeAt(index);
                                  });
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildImageGrid(
                    title: 'Фотографии вещи',
                    description: 'Добавьте основной вид, спину или другие ракурсы.',
                    images: item.garmentImages,
                    itemIndex: index,
                    forLabels: false,
                    colorScheme: colorScheme,
                    onAdd: _isLoading
                        ? null
                        : () => _showAddImageOptions(forLabels: false, itemIndex: index),
                    onSetPrimary: (photoIndex) => _setAsPrimary(photoIndex, index),
                  ),
                  const SizedBox(height: 18),
                  _buildImageGrid(
                    title: 'Фотографии бирок',
                    description: 'Прикрепите бирку или информацию по уходу за вещью.',
                    images: item.labelImages,
                    itemIndex: index,
                    forLabels: true,
                    colorScheme: colorScheme,
                    onAdd: _isLoading
                        ? null
                        : () => _showAddImageOptions(forLabels: true, itemIndex: index),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _items.add(_ClothingDraft());
                  });
                },
          icon: const Icon(Icons.add),
          label: const Text('Добавить ещё одну вещь'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Первое фото станет главным. Для пакетной загрузки используйте одинаковое число фото на каждую вещь.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
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
              : const Text('Далее'),
        ),
      ],
    );
  }
}
