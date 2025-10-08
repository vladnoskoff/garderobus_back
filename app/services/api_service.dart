import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io';

class ApiService {
  static const String baseUrl = "http://aapanel-api.noksovsteam.ru";
  static final storage = FlutterSecureStorage();

  static Future<int?> getStoredUserId() async {
    final id = await storage.read(key: "user_id");
    if (id == null) return null;
    return int.tryParse(id);
  }

  static Future<String?> getCachedThemePreference() async {
    final theme = await storage.read(key: "theme_preference");
    if (theme == null || theme.trim().isEmpty) {
      return null;
    }
    return theme;
  }

  static Future<void> cacheThemePreference(String theme) async {
    await storage.write(key: "theme_preference", value: theme);
  }

  static Future<String?> fetchThemePreference(int userId) async {
    try {
      final user = await getUser(userId);
      final preference = user['theme_preference'];
      if (preference is String && preference.trim().isNotEmpty) {
        return preference;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateThemePreference(int userId, String theme) async {
    await updateUser(userId, 'theme_preference', theme);
    await cacheThemePreference(theme);
  }

  static Future<void> rememberUserTheme(int userId) async {
    final remoteTheme = await fetchThemePreference(userId);
    if (remoteTheme != null) {
      await cacheThemePreference(remoteTheme);
    }
  }

  // Регистрация пользователя
  static Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
    String gender, {
    String? pinCode,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/users/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "email": email,
        "password": password,
        "gender": gender,
        if (pinCode != null && pinCode.trim().isNotEmpty) "pin_code": pinCode.trim(),
      }),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      if (response.body.isEmpty) {
        return {};
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return {};
    }
    throw Exception("Ошибка регистрации");
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
      await storage.write(
        key: "user_id",
        value: data["user_id"].toString(),
      );
      await cacheHasPin(data["has_pin"] == true);
      final userId = int.tryParse(data["user_id"].toString());
      if (userId != null) {
        await rememberUserTheme(userId);
      }
      return data;
    } else {
      throw Exception("Ошибка входа");
    }
  }

  // Получение информации о пользователе
  static Future<Map<String, dynamic>> getUser(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/users/$userId'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      await cacheHasPin(data['has_pin'] == true);
      return data;
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
    if (field == 'pin_code') {
      await cacheHasPin(value.trim().isNotEmpty);
    }
  }

  static Future<void> cacheHasPin(bool hasPin) async {
    await storage.write(key: "has_pin", value: hasPin ? 'true' : 'false');
  }

  static Future<bool> loadCachedHasPin() async {
    final value = await storage.read(key: "has_pin");
    return value == 'true';
  }

  static Future<bool> verifyPin(int userId, String pinCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/verify_pin'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"pin_code": pinCode}),
    );

    if (response.statusCode == 200) {
      return true;
    }

    if (response.statusCode == 401) {
      return false;
    }

    throw Exception('Не удалось проверить PIN-код');
  }

  static Future<void> setPinCode(int userId, String pinCode) async {
    await updateUser(userId, 'pin_code', pinCode);
  }

  static Future<void> clearPinCode(int userId) async {
    await updateUser(userId, 'pin_code', '');
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
  static Future<List<dynamic>> getUserClothes(int userId, {int? locationId}) async {
    final uri = locationId != null
        ? Uri.parse('$baseUrl/clothes/user/$userId?location_id=$locationId')
        : Uri.parse('$baseUrl/clothes/user/$userId');
    final response = await http.get(uri);

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
    bool autoFill = false,
    int? locationId,
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
      ..fields['color'] = color
      ..fields['auto_fill'] = autoFill.toString();

    if (material != null && material.isNotEmpty) {
      request.fields['material'] = material;
    }

    if (locationId != null) {
      request.fields['location_id'] = locationId.toString();
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
  static Future<Map<String, dynamic>> getWeatherByUserId(int userId, {int? locationId}) async {
    final uri = locationId != null
        ? Uri.parse('$baseUrl/weather/user/$userId?location_id=$locationId')
        : Uri.parse('$baseUrl/weather/user/$userId');
    final response = await http.get(uri);
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
  static Future<Map<String, dynamic>> getOutfit(int userId, {int? locationId}) async {
    final uri = locationId != null
        ? Uri.parse('$baseUrl/outfits/$userId?location_id=$locationId')
        : Uri.parse('$baseUrl/outfits/$userId');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Ошибка при получении наряда");
    }
  }


  // Получить историю нарядов
  static Future<List<dynamic>> getOutfitHistory(int userId, {int? locationId}) async {
    final uri = locationId != null
        ? Uri.parse("$baseUrl/outfits/history/$userId?location_id=$locationId")
        : Uri.parse("$baseUrl/outfits/history/$userId");
    final response = await http.get(uri);
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

  static Future<List<Map<String, dynamic>>> getMannequins(
    int userId, {
    int? locationId,
    int count = 3,
  }) async {
    final queryParameters = <String, String>{
      if (locationId != null) 'location_id': locationId.toString(),
    };

    Future<List<Map<String, dynamic>>> fetchBatch() async {
      final baseUri = Uri.parse("$baseUrl/ai/mannequin/$userId");
      final uri = queryParameters.isEmpty
          ? baseUri
          : baseUri.replace(queryParameters: queryParameters);

      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Ошибка при получении манекенов');
      }

      final dynamic data = json.decode(utf8.decode(response.bodyBytes));

      Map<String, dynamic> normalizeMap(Map source) {
        return source.map((key, value) => MapEntry(key.toString(), value));
      }

      if (data is List) {
        return data.whereType<Map>().map((item) => normalizeMap(item as Map)).toList();
      }

      if (data is Map) {
        final mapData = normalizeMap(data as Map);
        final mannequinsList = mapData['mannequins'];
        if (mannequinsList is List) {
          return mannequinsList
              .whereType<Map>()
              .map((item) => normalizeMap(item as Map))
              .toList();
        }
        return [mapData];
      }

      return [];
    }

    final List<Map<String, dynamic>> mannequins = [];
    final Set<String> seenImages = {};
    int attempts = 0;

    while (mannequins.length < count && attempts < count * 2) {
      attempts += 1;
      final batch = await fetchBatch();
      if (batch.isEmpty) {
        break;
      }

      bool added = false;
      for (final raw in batch) {
        final map = raw.map((key, value) => MapEntry(key.toString(), value));
        final imageUrl = map['image_url']?.toString() ?? map['imageUrl']?.toString();
        if (imageUrl != null && seenImages.contains(imageUrl)) {
          continue;
        }
        if (imageUrl != null) {
          seenImages.add(imageUrl);
        }
        mannequins.add(map);
        added = true;
        if (mannequins.length >= count) {
          break;
        }
      }

      if (!added) {
        break;
      }
    }

    return mannequins.take(count).toList();
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

  static Future<List<dynamic>> getWardrobeLocations(int userId) async {
    final response = await http.get(Uri.parse('$baseUrl/locations/$userId'));
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Ошибка при получении локаций гардероба');
    }
  }

  static Future<Map<String, dynamic>> createWardrobeLocation({
    required int userId,
    required String name,
    double? latitude,
    double? longitude,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/locations/$userId'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "name": name,
        "latitude": latitude,
        "longitude": longitude,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Ошибка при создании локации');
    }
  }

  static Future<Map<String, dynamic>> updateWardrobeLocation({
    required int userId,
    required int locationId,
    String? name,
    double? latitude,
    double? longitude,
  }) async {
    final Map<String, dynamic> payload = {};
    if (name != null) {
      payload['name'] = name;
    }
    if (latitude != null) {
      payload['latitude'] = latitude;
    }
    if (longitude != null) {
      payload['longitude'] = longitude;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/locations/$userId/$locationId'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('Ошибка при обновлении локации');
    }
  }

  static Future<void> deleteWardrobeLocation({
    required int userId,
    required int locationId,
  }) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/locations/$userId/$locationId'),
    );

    if (response.statusCode != 200) {
      throw Exception('Ошибка при удалении локации');
    }
  }
}
