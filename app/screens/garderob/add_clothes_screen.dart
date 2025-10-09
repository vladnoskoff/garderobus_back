import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';

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
  File? _image;
  bool _isLoading = false;
  bool _useAiAutoFill = false;
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



  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (pickedFile != null) {
        setState(() {
          _image = File(pickedFile.path);
        });
      }
    } on PlatformException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'Не удалось открыть камеру: ${e.message ?? e.code}'
                : 'Не удалось открыть галерею: ${e.message ?? e.code}',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка при выборе изображения: $e'),
        ),
      );
    }
  }

  Future<void> submit() async {
    if (!_useAiAutoFill && !_formKey.currentState!.validate()) {
      return;
    }

    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите изображение')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ApiService.addClothes(
        name: _useAiAutoFill ? '' : _nameController.text.trim(),
        category: _useAiAutoFill ? '' : _categoryController.text.trim(),
        season: _useAiAutoFill ? '' : season,
        color: _useAiAutoFill ? '' : _colorController.text.trim(),
        material: _materialController.text.trim().isEmpty
            ? null
            : _materialController.text.trim(),
        image: _image!,
        autoFill: _useAiAutoFill,
        locationId: _selectedLocationId,
      );

      if (!mounted) return;
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
    return Scaffold(
      appBar: AppBar(title: Text('Добавить одежду')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  DropdownButtonFormField<bool>(
                    value: _useAiAutoFill,
                    decoration: const InputDecoration(
                      labelText: 'Заполнение данных',
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
                      decoration: const InputDecoration(
                        labelText: 'Локация гардероба',
                      ),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Без привязки'),
                        ),
                        ..._locations
                            .whereType<Map<String, dynamic>>()
                            .map((loc) {
                          final parsedId = _parseLocationId(loc['id']);
                          if (parsedId == null) {
                            return null;
                          }
                          final name = loc['name']?.toString() ?? 'Без названия';
                          return DropdownMenuItem<int?>(
                            value: parsedId,
                            child: Text(name),
                          );
                        }).whereType<DropdownMenuItem<int?>>(),
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
                  const SizedBox(height: 16),
                  if (!_useAiAutoFill) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Название'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите название';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(labelText: 'Категория'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите категорию';
                        }
                        return null;
                      },
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Сезон'),
                      value: season.isNotEmpty ? season : null,
                      items: ['Лето', 'Осень', 'Зима', 'Весна']
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
                    TextFormField(
                      controller: _colorController,
                      decoration: const InputDecoration(labelText: 'Цвет'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите цвет';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _materialController,
                      decoration:
                          const InputDecoration(labelText: 'Материал (необязательно)'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_image != null)
                    Column(
                      children: [
                        Text('Предпросмотр изображения:'),
                        const SizedBox(height: 8),
                        Image.file(_image!, height: 200),
                      ],
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: Icon(Icons.camera_alt),
                        label: Text('Камера'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: Icon(Icons.image),
                        label: Text('Галерея'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _isLoading ? null : submit,
                    child: _isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('Добавить'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
 