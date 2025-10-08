import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';
import '../../services/clothes.dart';
import 'add_clothes_screen.dart';
import 'clothes_detail_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  _WardrobeScreenState createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  List<Clothes> clothes = [];
  bool isLoading = true;
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    fetchClothes();
  }

  Future<void> fetchClothes() async {
    try {
      final userId = await storage.read(key: 'user_id');
      if (userId == null) {
        throw Exception("Пользователь не найден");
      }

      final response = await ApiService.getUserClothes(int.parse(userId));
      setState(() {
        clothes = response.map((json) => Clothes.fromJson(json)).toList().cast<Clothes>();
        isLoading = false;
      });
    } catch (e) {
      print("Ошибка при загрузке одежды: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> confirmAndDeleteClothes(int clothesId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить вещь'),
        content: Text('Вы уверены, что хотите удалить эту вещь?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.deleteClothes(clothesId);
      fetchClothes();
    }
  }

  void navigateToAddClothes() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddClothesScreen()),
    ).then((_) => fetchClothes());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Гардеробус'),
        centerTitle: true,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GestureDetector(
                    onTap: navigateToAddClothes,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.lightBlueAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.add,
                          color: Colors.black,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: clothes.length,
                      itemBuilder: (context, index) {
                        final item = clothes[index];
                        return GestureDetector(
                          onTap: () async {
                            final deleted = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClothesDetailScreen(clothes: item),
                              ),
                            );
                            if (deleted == true) {
                              fetchClothes();
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF62DEFA),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 12,
                                  top: 18,
                                  right: 35, // или ограничь ширину вручную
                                  child: Container(
                                    height: 127,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      image: item.imageUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(item.imageUrl!),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFCFDDE0),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Icon(
                                      Icons.edit,
                                      color: Colors.black,
                                      size: 16,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 8,
                                  bottom: 8,
                                  child: GestureDetector(
                                    onTap: () => confirmAndDeleteClothes(item.id!),
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF0D0D),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
