import 'package:flutter/material.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  _PlacesScreenState createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final List<Map<String, String>> places = [
    {'name': 'Дом 1', 'icon': 'home'},
    {'name': 'Работа 1', 'icon': 'work'},
    {'name': 'Место 1', 'icon': 'place'},
  ];

  void editPlace(int index) {
    TextEditingController controller = TextEditingController(text: places[index]['name']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Редактировать место'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: 'Название места'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  places[index]['name'] = controller.text;
                });
                Navigator.pop(context);
              },
              child: Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  void deletePlace(int index) {
    setState(() {
      places.removeAt(index);
    });
  }

  void addPlace() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Добавить место'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: 'Название места'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  places.add({'name': controller.text, 'icon': 'place'});
                });
                Navigator.pop(context);
              },
              child: Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Места'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: places.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: EdgeInsets.only(bottom: 16),
                    width: double.infinity,
                    height: 59,
                    decoration: BoxDecoration(
                      color: const Color(0xFF62DEFA),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 10),
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Color(0xFFD9D9D9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            index == 0 ? Icons.home : index == 1 ? Icons.work : Icons.location_on,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            places[index]['name']!,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => editPlace(index),
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFCFDDE0),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => deletePlace(index),
                          child: Container(
                            width: 30,
                            height: 30,
                            margin: EdgeInsets.only(right: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF0D0D),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: addPlace,
        backgroundColor: Color(0xFFCFDDE0),
        child: Icon(
          Icons.add,
          color: Colors.black,
        ),
      ),
    );
  }
}
