import 'package:flutter/material.dart';
import '../../services/clothes.dart';
import '../../services/api_service.dart';

class ClothesDetailScreen extends StatelessWidget {
  final Clothes clothes;

  const ClothesDetailScreen({Key? key, required this.clothes}) : super(key: key);

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить вещь?'),
        content: Text('Вы действительно хотите удалить эту вещь из гардероба?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService.deleteClothes(clothes.id);
      Navigator.pop(context, true); // Возвращаем значение true, чтобы обновить список
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Гардеробус'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                clothes.imageUrl ?? '',
                fit: BoxFit.cover,
                height: 300,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              clothes.name,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Icon(Icons.checkroom, size: 32),
                    Text('${clothes.category}'),
                  ],
                ),
                Column(
                  children: [
                    Icon(Icons.thermostat, size: 32),
                    Text('${clothes.season}'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
 