import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';

class ApiService {
  static const String baseUrl = "http://aapanel-api.noksovsteam.ru";
  static final storage = FlutterSecureStorage();

  // Регистрация пользователя
  static Future<void> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/users/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"name": name, "email": email, "password": password}),
    );
    if (response.statusCode != 200) {
      throw Exception("Ошибка регистрации");
    }
  }

  // Логин пользователя
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/users/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await storage.write(key: "token", value: data["access_token"]);
      await storage.write(key: "user_id", value: data["user_id"].toString());// <-- вот здесь
      return data;
    } else {
      throw Exception("Ошибка входа");
    }
  }

  // Получение информации о пользователе
  static Future<Map<String, dynamic>> getUser(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/users/$userId'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Ошибка при получении данных пользователя');
    }
  }

  // Удаление пользователя
  static Future<void> deleteUser(int userId) async {
    final token = await storage.read(key: "token");
    final response = await http.delete(
      Uri.parse("$baseUrl/users/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Ошибка при удалении пользователя");
    }
  }

  // Обновление данных пользователя
  static Future<void> updateUser(int userId, String field, String value) async {
    final token = await storage.read(key: "token");
    final url = Uri.parse('$baseUrl/users/$userId');

    final body = jsonEncode({field: value});

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: body,
    );

    if (response.statusCode != 200) {
      throw Exception("Ошибка при обновлении пользователя");
    }
  }

  // Обновление стиля
  static Future<void> updateStyle(int userId, String style) async {
    final token = await storage.read(key: "token");
    final response = await http.put(
      Uri.parse("$baseUrl/users/$userId/style?style=$style"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode != 200) {
      throw Exception("Ошибка обновления стиля");
    }
  }

  // Обновление API-ключей
  static Future<void> updateApiKeys(int userId, String openaiKey, String weatherKey) async {
    final token = await storage.read(key: "token");
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/update_keys'),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "openai_api_key": openaiKey,
        "weather_api_key": weatherKey,
      }),
    );
    if (response.statusCode != 200) {
      throw Exception("Ошибка при обновлении API-ключей");
    }
  }
  
  // Обновление координат
  static Future<void> updateLocation(int userId, String location) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'location': location}),
    );

    if (response.statusCode != 200) {
      throw Exception('Не удалось обновить координаты');
    }
  }

  // Получение сохраненного токена
  static Future<String?> getToken() async {
    return await storage.read(key: "token");
  }



//--------------------------------------------------------------------------------------------------------------
  // Получить список одежды
  static Future<List<dynamic>> getClothes() async {
    final response = await http.get(Uri.parse("$baseUrl/clothes/"));
    
    if (response.statusCode == 200) {
      final utf8Response = utf8.decode(response.bodyBytes); // Декодируем в utf8
      print("Ответ от сервера: $utf8Response"); // Выводим ответ в консоль Flutter
      return jsonDecode(utf8Response);
    } else {
      throw Exception("Ошибка при загрузке одежды: ${response.statusCode}");
    }
  }

  // Получение одежды пользователя
  static Future<List<dynamic>> getUserClothes(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/clothes/user/$userId'));

    if (response.statusCode == 200) {
      final utf8Response = utf8.decode(response.bodyBytes); // Для корректной обработки русских символов
      return jsonDecode(utf8Response);
    } else {
      throw Exception('Ошибка при получении одежды пользователя');
    }
  }

  // Добовление одежды пользователя
  static Future<void> addClothes({
    required String name,
    required String category,
    required String season,
    required String color,
    String? material,
    required File image,
  }) async {
    final storage = const FlutterSecureStorage();
    final userId = await storage.read(key: "user_id");

    if (userId == null) {
      throw Exception("user_id не найден в хранилище");
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/clothes/'),
    )
      ..fields['user_id'] = userId
      ..fields['name'] = name
      ..fields['category'] = category
      ..fields['season'] = season
      ..fields['color'] = color;

    if (material != null && material.isNotEmpty) {
      request.fields['material'] = material;
    }

    request.files.add(await http.MultipartFile.fromPath('file', image.path));

    final response = await request.send();

    if (response.statusCode != 200) {
      final respStr = await response.stream.bytesToString();
      print("Ошибка при добавлении: $respStr");
      throw Exception("Ошибка добавления одежды");
    }
  }

  // Загрузка изображения
  static Future<String> uploadImage(File image) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/clothes/upload-image/'),
    );
    request.files.add(
      await http.MultipartFile.fromPath('file', image.path),
    );

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var result = jsonDecode(responseData);

    if (response.statusCode == 200) {
      return result['image_url'];
    } else {
      throw Exception('Ошибка при загрузке изображения');
    }
  }

  // Удалить вещь
  static Future<void> deleteClothes(int clothesId) async {
    final response = await http.delete(Uri.parse("$baseUrl/clothes/$clothesId"));
    if (response.statusCode != 200) {
      throw Exception('Ошибка при удалении одежды');
    }
  }

//------------------------------------------------------------------------------------------------------------------------------------

  // Получить погоды
  static Future<Map<String, dynamic>> getWeather(String city) async {
    final response = await http.get(Uri.parse('$baseUrl/weather/$city'));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)); // <- поддержка кириллицы
    } else {
      throw Exception('Ошибка при получении погоды');
    }
  }
  
  // Получить погоды по координатам
  static Future<Map<String, dynamic>> getWeatherByUserId(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/weather/user/$userId'));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Ошибка получения погоды по координатам');
    }
  }

//------------------------------------------------------------------------------------------------------------------------------------

  /* // Получение наряда по погоде
  static Future<Map<String, dynamic>> getOutfit(int userId, String city) async {
    final response = await http.get(Uri.parse('$baseUrl/outfits/$userId/$city'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Ошибка при получении наряда");
    }
  } */

  // Получение наряда по погоде координатам пользователя
  static Future<Map<String, dynamic>> getOutfit(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/outfits/$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Ошибка при получении наряда");
    }
  }


  // Получить историю нарядов
  static Future<List<dynamic>> getOutfitHistory(int userId) async {
    final response = await http.get(Uri.parse("$baseUrl/outfits/history/$userId"));
    return jsonDecode(response.body);
  }

  // Оценка наряда
  static Future<void> rateOutfit(int outfitId, int rating) async {
    final response = await http.put(
      Uri.parse("$baseUrl/outfits/rate/$outfitId?rating=$rating"),
    );
    if (response.statusCode != 200) {
      throw Exception("Ошибка при обновлении рейтинга");
    }
  }

  // Получить рекомендации от ИИ
  static Future<String> getAIRecommendation(int userId) async {
    final response = await http.get(Uri.parse("$baseUrl/ai/recommendation/$userId"));
    return jsonDecode(response.body)["recommendation"];
  }

  // Получить визуальное изображение наряда
  static Future<String> getVisualOutfit(int userId) async {
    final response = await http.get(Uri.parse("$baseUrl/ai/visual-recommendation/$userId"));
    return jsonDecode(response.body)["image_url"];
  }

  // Получить часто используемые вещи
  static Future<List<dynamic>> getMostWornClothes(int userId) async {
    final response = await http.get(Uri.parse("$baseUrl/analytics/most_worn/$userId"));
    return jsonDecode(response.body);
  }

  // Получить забытые вещи
  static Future<List<dynamic>> getLeastWornClothes(int userId) async {
    final response = await http.get(Uri.parse("$baseUrl/analytics/least_worn/$userId"));
    return jsonDecode(response.body);
  }
}
