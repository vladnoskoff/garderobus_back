import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'clothes.dart';
import 'local_storage_service.dart';
import 'network_service.dart';
import 'pending_action_queue.dart';

class SyncService {
  SyncService._();

  static final SyncService instance = SyncService._();
  final ValueNotifier<bool> isSyncing = ValueNotifier<bool>(false);

  Future<void> initialize() async {
    await NetworkService.initialize();
    NetworkService.isOnline.addListener(() {
      if (NetworkService.isOnline.value) {
        syncPendingActions();
      }
    });
    await syncPendingActions();
  }

  Future<void> syncPendingActions() async {
    if (isSyncing.value) return;
    if (!NetworkService.isOnline.value) return;

    isSyncing.value = true;
    try {
      final queue = await PendingActionQueue.loadQueue();
      for (final action in queue) {
        final success = await _processAction(action);
        if (success) {
          await PendingActionQueue.markDone(action.id);
        } else {
          await PendingActionQueue.incrementRetry(action.id);
        }
      }
    } finally {
      isSyncing.value = false;
    }
  }

  Future<bool> _processAction(PendingAction action) async {
    try {
      switch (action.entity) {
        case 'clothes':
          return await _syncClothes(action);
        default:
          return true;
      }
    } catch (_) {
      return false;
    }
  }

  Future<bool> _syncClothes(PendingAction action) async {
    if (action.type == PendingActionType.create) {
      final payload = action.payload;
      final images = (payload['images'] as List?)?.cast<String>().map(File.new).toList() ?? [];
      await ApiService.addClothes(
        name: payload['name'] ?? '',
        category: payload['category'] ?? '',
        season: payload['season'] ?? '',
        color: payload['color'] ?? '',
        material: payload['material'],
        images: images,
        autoFill: payload['auto_fill'] == true,
        locationId: payload['location_id'] as int?,
        promptDescription: payload['prompt_description'],
        careInstructions: payload['care_instructions'],
      );
      final userId = int.tryParse('${payload['user_id']}');
      if (userId != null) {
        await LocalStorageService.cacheClothes(
          userId,
          await ApiService.getUserClothes(userId),
        );
      }
      return true;
    }

    final clothesId = int.tryParse('${action.payload['id']}');
    if (clothesId == null) return true;
    await ApiService.updateClothes(
      clothesId: clothesId,
      name: action.payload['name'],
      category: action.payload['category'],
      season: action.payload['season'],
      color: action.payload['color'],
      material: action.payload['material'],
      promptDescription: action.payload['prompt_description'],
      careInstructions: action.payload['care_instructions'],
      temperatureMin: action.payload['temperature_min'] as int?,
      temperatureMax: action.payload['temperature_max'] as int?,
      locationId: action.payload['location_id'] as int?,
      aiMetadata: action.payload['ai_metadata'] as Map<String, dynamic>?,
    );
    return true;
  }

  Future<void> enqueueClothesCreate({
    required int userId,
    required String name,
    required String category,
    required String season,
    required String color,
    required List<File> images,
    String? material,
    bool autoFill = false,
    int? locationId,
    String? promptDescription,
    String? careInstructions,
  }) async {
    final action = PendingAction(
      id: PendingActionQueue.buildActionId(),
      entity: 'clothes',
      type: PendingActionType.create,
      payload: {
        'user_id': userId,
        'name': name,
        'category': category,
        'season': season,
        'color': color,
        'material': material,
        'auto_fill': autoFill,
        'location_id': locationId,
        'prompt_description': promptDescription,
        'care_instructions': careInstructions,
        'images': images.map((e) => e.path).toList(),
      },
      createdAt: DateTime.now(),
    );
    await PendingActionQueue.enqueue(action);
  }

  Future<void> enqueueClothesUpdate({
    required int clothesId,
    required Map<String, dynamic> body,
  }) async {
    final action = PendingAction(
      id: PendingActionQueue.buildActionId(),
      entity: 'clothes',
      type: PendingActionType.update,
      payload: {
        'id': clothesId,
        ...body,
      },
      createdAt: DateTime.now(),
    );
    await PendingActionQueue.enqueue(action);
  }
}
