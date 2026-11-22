import 'package:flutter/foundation.dart';

class NamedItem {
  final String name;

  const NamedItem({required this.name});

  factory NamedItem.fromJson(dynamic json) {
    final raw = json is Map ? json['name'] : json;
    return NamedItem(name: raw?.toString().trim() ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'name': name};
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is NamedItem && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

class CommandsStore {
  static List<String> _commands = [];
  static VoidCallback? _onChangedCallback;

  static List<String> get commands => List.unmodifiable(_commands);

  static void setOnChangedCallback(VoidCallback? callback) {
    _onChangedCallback = callback;
  }

  static void setCommands(List<String> commands) {
    _commands = List.of(commands);
    _onChangedCallback?.call();
  }

  static void loadFromJson(dynamic json) {
    if (json is List) {
      final parsed = <String>[];
      final seen = <String>{};

      for (final entry in json) {
        final value = entry?.toString().trim() ?? '';
        if (value.isNotEmpty && seen.add(value)) {
          parsed.add(value);
        }
      }

      _commands = parsed;
      return;
    }

    _commands = [];
  }

  static List<String> toJson() {
    return List.of(_commands);
  }
}

class TriggersStore {
  static List<NamedItem> _triggers = [];
  static VoidCallback? _onChangedCallback;

  static List<NamedItem> get triggers => List.unmodifiable(_triggers);

  static void setOnChangedCallback(VoidCallback? callback) {
    _onChangedCallback = callback;
  }

  static void setTriggers(List<NamedItem> triggers) {
    _triggers = List.of(triggers);
    _onChangedCallback?.call();
  }

  static void loadFromJson(dynamic json) {
    if (json is List) {
      final parsed = <NamedItem>[];
      final seen = <String>{};

      for (final entry in json) {
        final item = NamedItem.fromJson(entry);
        final value = item.name.trim();
        if (value.isNotEmpty && seen.add(value)) {
          parsed.add(NamedItem(name: value));
        }
      }

      _triggers = parsed;
      return;
    }

    _triggers = [];
  }

  static List<Map<String, dynamic>> toJson() {
    return [for (final item in _triggers) item.toJson()];
  }
}

class ControllerSettingsStore {
  static List<NamedItem> _settings = [];
  static VoidCallback? _onChangedCallback;

  static List<NamedItem> get settings => List.unmodifiable(_settings);

  static void setOnChangedCallback(VoidCallback? callback) {
    _onChangedCallback = callback;
  }

  static void setSettings(List<NamedItem> settings) {
    _settings = List.of(settings);
    _onChangedCallback?.call();
  }

  static void loadFromJson(dynamic json) {
    if (json is List) {
      final parsed = <NamedItem>[];
      final seen = <String>{};

      for (final entry in json) {
        final item = NamedItem.fromJson(entry);
        final value = item.name.trim();
        if (value.isNotEmpty && seen.add(value)) {
          parsed.add(NamedItem(name: value));
        }
      }

      _settings = parsed;
      return;
    }

    _settings = [];
  }

  static List<Map<String, dynamic>> toJson() {
    return [for (final item in _settings) item.toJson()];
  }
}

class HeadingStratsStore {
  static List<NamedItem> _headingStrats = [];
  static VoidCallback? _onChangedCallback;

  static List<NamedItem> get headingStrats => List.unmodifiable(_headingStrats);

  static void setOnChangedCallback(VoidCallback? callback) {
    _onChangedCallback = callback;
  }

  static void setHeadingStrats(List<NamedItem> headingStrats) {
    _headingStrats = List.of(headingStrats);
    _onChangedCallback?.call();
  }

  static void loadFromJson(dynamic json) {
    if (json is List) {
      final parsed = <NamedItem>[];
      final seen = <String>{};

      for (final entry in json) {
        final item = NamedItem.fromJson(entry);
        final value = item.name.trim();
        if (value.isNotEmpty && seen.add(value)) {
          parsed.add(NamedItem(name: value));
        }
      }

      _headingStrats = parsed;
      return;
    }

    _headingStrats = [];
  }

  static List<Map<String, dynamic>> toJson() {
    return [for (final item in _headingStrats) item.toJson()];
  }
}

class GoalsStore {
  static List<NamedItem> _goals = [];
  static VoidCallback? _onChangedCallback;

  static List<NamedItem> get goals => List.unmodifiable(_goals);

  static void setOnChangedCallback(VoidCallback? callback) {
    _onChangedCallback = callback;
  }

  static void setGoals(List<NamedItem> goals) {
    _goals = List.of(goals);
    _onChangedCallback?.call();
  }

  static void loadFromJson(dynamic json) {
    if (json is List) {
      final parsed = <NamedItem>[];
      final seen = <String>{};

      for (final entry in json) {
        final item = NamedItem.fromJson(entry);
        final value = item.name.trim();
        if (value.isNotEmpty && seen.add(value)) {
          parsed.add(NamedItem(name: value));
        }
      }

      _goals = parsed;
      return;
    }

    _goals = [];
  }

  static List<Map<String, dynamic>> toJson() {
    return [for (final item in _goals) item.toJson()];
  }
}