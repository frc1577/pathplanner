import 'dart:convert';
import 'dart:io';

import 'package:pathplanner/path/goal.dart';
import 'package:pathplanner/path/goal_picker.dart';

class GoalPickerSyncService {
  static final Map<String, GoalPicker> _pickersByKey = {};
  static final Map<String, File> _pickerFilesByKey = {};

  static void registerPicker(
    String key,
    GoalPicker picker, {
    File? file,
  }) {
    _pickersByKey[key] = picker;
    if (file != null) {
      _pickerFilesByKey[key] = file;
    }
  }

  static void unregisterPicker(String key) {
    _pickersByKey.remove(key);
    _pickerFilesByKey.remove(key);
  }

  static void clearRegisteredPickers() {
    _pickersByKey.clear();
    _pickerFilesByKey.clear();
  }

  static bool syncGoalInGoalPicker(
    GoalPicker picker,
    Goal updatedGoal, {
    String? previousName,
  }) {
    final targetNames = <String>{
      updatedGoal.name.trim(),
      if (previousName != null && previousName.trim().isNotEmpty)
        previousName.trim(),
    };

    bool modified = false;
    final updatedJson = updatedGoal.toJson();

    for (int i = 0; i < picker.goals.length; i++) {
      final existing = picker.goals[i];
      if (targetNames.contains(existing.name.trim())) {
        picker.goals[i] = Goal.fromJson(Map<String, dynamic>.from(updatedJson));
        modified = true;
      }
    }

    return modified;
  }

  static Future<void> syncGoalAcrossPickersAndSave({
    required Goal updatedGoal,
    String? previousName,
    Map<String, GoalPicker>? pickersByKey,
    Map<String, File>? pickerFilesByKey,
  }) async {
    final activePickers = pickersByKey ?? _pickersByKey;
    final activeFiles = pickerFilesByKey ?? _pickerFilesByKey;
    const encoder = JsonEncoder.withIndent('  ');

    for (final entry in activePickers.entries) {
      final key = entry.key;
      final picker = entry.value;
      final changed = syncGoalInGoalPicker(
        picker,
        updatedGoal,
        previousName: previousName,
      );

      if (changed) {
        final file = activeFiles[key];
        if (file != null) {
          await file.parent.create(recursive: true);
          await file.writeAsString(encoder.convert(picker.toJson()));
        }
      }
    }
  }
}