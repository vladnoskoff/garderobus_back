import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';

class AddClothesScreen extends StatefulWidget {
  const AddClothesScreen({super.key});

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
      setState(() {
        _locations = locations;
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
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
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
                        ..._locations.map((loc) {
                          final name = loc['name']?.toString() ?? 'Без названия';
                          return DropdownMenuItem<int?>(
                            value: loc['id'] as int,
                            child: Text(name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedLocationId = value;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_useAiAutoFill,
                    decoration: const InputDecoration(labelText: 'Название'),
                    validator: (value) {
                      if (_useAiAutoFill) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите название';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _categoryController,
                    enabled: !_useAiAutoFill,
                    decoration: const InputDecoration(labelText: 'Категория'),
                    validator: (value) {
                      if (_useAiAutoFill) return null;
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
                    onChanged: _useAiAutoFill
                        ? null
                        : (value) {
                            setState(() {
                              season = value ?? '';
                            });
                          },
                    validator: (value) {
                      if (_useAiAutoFill) return null;
                      if (value == null || value.isEmpty) {
                        return 'Выберите сезон';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _colorController,
                    enabled: !_useAiAutoFill,
                    decoration: const InputDecoration(labelText: 'Цвет'),
                    validator: (value) {
                      if (_useAiAutoFill) return null;
                      if (value == null || value.trim().isEmpty) {
                        return 'Введите цвет';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _materialController,
                    decoration: const InputDecoration(labelText: 'Материал (необязательно)'),
                  ),
                  const SizedBox(height: 16),
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
 