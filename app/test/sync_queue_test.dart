import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/clothes.dart';
import '../services/local_storage_service.dart';
import '../services/pending_action_queue.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    await LocalStorageService.initialize();
  });

  tearDown(() async {
    if (Hive.isBoxOpen('clothes_box')) {
      await Hive.box('clothes_box').clear();
    }
    if (Hive.isBoxOpen('outfits_box')) {
      await Hive.box('outfits_box').clear();
    }
  });

  test('pending actions are enqueued and loaded', () async {
    final action = PendingAction(
      id: PendingActionQueue.buildActionId(),
      entity: 'clothes',
      type: PendingActionType.create,
      payload: {'name': 'Test'},
      createdAt: DateTime.now(),
    );

    await PendingActionQueue.enqueue(action);
    final queue = await PendingActionQueue.loadQueue();

    expect(queue.length, 1);
    expect(queue.first.payload['name'], 'Test');
  });

  test('local clothes cache stores and returns data', () async {
    const userId = 1;
    final clothes = Clothes(
      id: 1,
      userId: userId,
      name: 'Тест',
      category: 'Категория',
      season: 'Зима',
      color: 'Белый',
      createdAt: DateTime(2024, 1, 1),
      isPending: true,
    );

    await LocalStorageService.cacheClothes(userId, [clothes]);
    final cached = await LocalStorageService.getCachedClothes(userId);

    expect(cached, isNotEmpty);
    expect(cached.first.isPending, true);
    expect(cached.first.name, 'Тест');
  });
}
