import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

enum PendingActionType { create, update }

typedef PendingPayload = Map<String, dynamic>;

class PendingAction {
  PendingAction({
    required this.id,
    required this.entity,
    required this.type,
    required this.payload,
    this.retries = 0,
    required this.createdAt,
  });

  final String id;
  final String entity;
  final PendingActionType type;
  final PendingPayload payload;
  final int retries;
  final DateTime createdAt;

  PendingAction copyWith({int? retries}) {
    return PendingAction(
      id: id,
      entity: entity,
      type: type,
      payload: payload,
      retries: retries ?? this.retries,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity': entity,
      'type': type.name,
      'payload': payload,
      'retries': retries,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      id: json['id'] as String,
      entity: json['entity'] as String,
      type: PendingActionType.values
          .firstWhere((v) => v.name == (json['type'] as String? ?? 'update'), orElse: () => PendingActionType.update),
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? {},
      retries: json['retries'] is int ? json['retries'] as int : int.tryParse('${json['retries']}') ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class PendingActionQueue {
  static const _queueBox = 'pending_actions_box';
  static const _queueKey = 'actions';

  static Future<Box<Map>> _ensureBox() async {
    if (!Hive.isBoxOpen(_queueBox)) {
      await Hive.openBox<Map>(_queueBox);
    }
    return Hive.box<Map>(_queueBox);
  }

  static Future<List<PendingAction>> loadQueue() async {
    final box = await _ensureBox();
    final raw = box.get(_queueKey);
    if (raw is Map && raw['items'] is List) {
      return (raw['items'] as List)
          .whereType<Map>()
          .map((item) => PendingAction.fromJson(item.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  static Future<void> saveQueue(List<PendingAction> actions) async {
    final box = await _ensureBox();
    await box.put(_queueKey, {
      'items': actions.map((a) => a.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> enqueue(PendingAction action) async {
    final queue = await loadQueue();
    await saveQueue([...queue, action]);
  }

  static Future<void> markDone(String actionId) async {
    final queue = await loadQueue();
    queue.removeWhere((a) => a.id == actionId);
    await saveQueue(queue);
  }

  static Future<void> incrementRetry(String actionId) async {
    final queue = await loadQueue();
    final updated = [
      for (final item in queue)
        if (item.id == actionId)
          item.copyWith(retries: item.retries + 1)
        else
          item,
    ];
    await saveQueue(updated);
  }

  static String buildActionId() => DateTime.now().microsecondsSinceEpoch.toString();

  static String dumpQueueForLogs(List<PendingAction> actions) =>
      const JsonEncoder.withIndent('  ').convert(actions.map((e) => e.toJson()).toList());
}
