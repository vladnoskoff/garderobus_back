import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';

class AddClothesScreen extends StatefulWidget {
  const AddClothesScreen({super.key});

  @override
  _AddClothesScreenState createState() => _AddClothesScreenState();
}

class _AddClothesScreenState extends State<AddClothesScreen> {
  final _formKey = GlobalKey<FormState>();
  String name = '';
  String category = '';
  String season = '';
  String color = '';
  String? material;
  String? imageUrl;
  File? _image;
  bool _isLoading = false;

  final picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> submit() async {
  if (_formKey.currentState!.validate()) {
    _formKey.currentState!.save();

    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Пожалуйста, выберите изображение')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await ApiService.addClothes(
      name: name,
      category: category,
      season: season,
      color: color,
      material: material,
      image: _image!,
    );

    setState(() {
      _isLoading = false;
    });

    Navigator.pop(context);
  }
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
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Название'),
                    onSaved: (value) => name = value!,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Категория'),
                    onSaved: (value) => category = value!,
                  ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Сезон'),
                    value: season.isNotEmpty ? season : null,
                    items: ['Лето', 'Осень', 'Зима', 'Весна']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        season = value!;
                      });
                    },
                    validator: (value) => value == null || value.isEmpty ? 'Выберите сезон' : null,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Цвет'),
                    onSaved: (value) => color = value!,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Материал (необязательно)'),
                    onSaved: (value) => material = value,
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
 