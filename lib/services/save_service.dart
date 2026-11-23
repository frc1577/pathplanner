import 'dart:async';

import 'package:pathplanner/namedObjects/named_controllersettings.dart';
import 'package:pathplanner/namedObjects/named_headingStrat.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/stores_Service.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

class SaveService {
  static Future<String> exportToCustomFormat(
    List<Waypoint> waypoints,
  ) async {
    Log.info(
      'Custom export hook invoked with ${waypoints.length} waypoints.',
    );

    String toVarName(String input, {String fallback = 'item'}) {
      if (input.trim().isEmpty) return fallback;

      final parts = input
          .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();

      if (parts.isEmpty) return fallback;

      final camel = parts
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join();

      var res = camel[0].toLowerCase() + camel.substring(1);

      if (RegExp(r'^[0-9]').hasMatch(res)) {
        res = '_$res';
      }

      return res;
    }

    final usedNames = <String>{};

    String uniqueVarName(String input, {String fallback = 'item'}) {
      final base = toVarName(input, fallback: fallback);
      var name = base;
      int i = 1;

      while (usedNames.contains(name)) {
        name = '${base}_$i';
        i++;
      }

      usedNames.add(name);
      return name;
    }

    final sb = StringBuffer();

    // 1. Export named ControllerSettings references from store
    final controllerItems = ControllerSettingsStore.settings;
    final controllerNameToVar = <String, String>{};

    for (final item in controllerItems) {
      final varName = uniqueVarName(item.name, fallback: 'controllerSetting');
      controllerNameToVar[item.name] = varName;
      sb.writeln(
        'public static final String $varName = "${_escapeJavaString(item.name)}";',
      );
    }

    if (controllerItems.isNotEmpty) sb.writeln();

    // 2. Export named HeadingStrats references from store
    final headingItems = HeadingStratsStore.headingStrats;
    final headingNameToVar = <String, String>{};

    for (final item in headingItems) {
      final varName = uniqueVarName(item.name, fallback: 'headingStrat');
      headingNameToVar[item.name] = varName;
      sb.writeln(
        'public static final String $varName = "${_escapeJavaString(item.name)}";',
      );
    }

    if (headingItems.isNotEmpty) sb.writeln();

    // 3. Export waypoints list
    sb.writeln(
      'static ArrayList<Waypoint> autoPath = new ArrayList<>(){{',
    );

    for (final w in waypoints) {
      final x = _formatNum(w.anchor.x);
      final y = _formatNum(w.anchor.y);
      final angleDeg = _formatNum(w.holonomicAngle.degrees);
      final tolerance = _formatNum(w.tolerance);
      final rotationTolerance = _formatNum(w.toleranceDeg);

      String controllerRef = 'null';
      final csName = w.controllerSettingName;
      if (csName != null && controllerNameToVar.containsKey(csName)) {
        controllerRef = controllerNameToVar[csName]!;
      } else if (csName != null && csName.isNotEmpty) {
        controllerRef = '"${_escapeJavaString(csName)}"';
      } else if (controllerItems.isNotEmpty) {
        controllerRef = controllerNameToVar[controllerItems.first.name]!;
      }

      String headingRef = 'null';
      final hsName = w.headingStratName;
      if (hsName != null && headingNameToVar.containsKey(hsName)) {
        headingRef = headingNameToVar[hsName]!;
      } else if (hsName != null && hsName.isNotEmpty) {
        headingRef = '"${_escapeJavaString(hsName)}"';
      } else if (headingItems.isNotEmpty) {
        headingRef = headingNameToVar[headingItems.first.name]!;
      }

      sb.writeln(
        '        add(new Waypoint(new Pose2d($x, $y, new Rotation2d(Math.toRadians($angleDeg))), $tolerance, $rotationTolerance, $controllerRef, $headingRef));',
      );
    }

    sb.writeln('    }};');

    return sb.toString();
  }

  static String _escapeJavaString(String s) =>
      s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  static String _formatNum(num? n) {
    if (n == null) return '0';
    if (n is int) return n.toString();

    final d = n.toDouble();
    if (d == d.roundToDouble()) {
      return d.round().toString();
    }
    return d.toString();
  }

  /// Parse Java `add(new Waypoint(...))` lines into [Waypoint] objects.
  /// Supports both 4-arg (with controller) and 5-arg (with controller + headingStrat) calls.
  static List<Waypoint> importFromJavaWaypoints(String input) {
    final lines = input.split(RegExp(r'\r?\n'));
    final waypoints = <Waypoint>[];

    final knownControllers = {
      for (final c in ControllerSettingsStore.settings) c.name,
    };
    final knownHeadings = {
      for (final h in HeadingStratsStore.headingStrats) h.name,
    };

    // Map exported Java constant declarations back to their string values if present
    final declaredStrings = _extractStringConstants(input);

    final pattern = RegExp(
      r'add\s*\(\s*new\s+Waypoint\s*\(\s*new\s+Pose2d\s*\(\s*([0-9+\-eE.]+)\s*,\s*([0-9+\-eE.]+)\s*,\s*new\s+Rotation2d\s*\(\s*Math\.toRadians\s*\(\s*([0-9+\-eE.]+)\s*\)\s*\)\s*\)\s*,\s*([0-9+\-eE.]+)\s*,\s*([0-9+\-eE.]+)(?:\s*,\s*([^,)]+))?(?:\s*,\s*([^)]+))?\s*\)',
      caseSensitive: false,
    );

    String? resolveName(String? rawArg, Set<String> knownSet) {
      if (rawArg == null) return null;
      final trimmed = rawArg.trim();
      if (trimmed.isEmpty || trimmed == 'null') return null;

      // Quoted literal: "mySetting"
      if (trimmed.startsWith('"') &&
          trimmed.endsWith('"') &&
          trimmed.length >= 2) {
        return trimmed.substring(1, trimmed.length - 1);
      }

      // Constant declared in the same snippet
      if (declaredStrings.containsKey(trimmed)) {
        return declaredStrings[trimmed];
      }

      // Strip class prefix like AutoConstants.mediumPID -> mediumPID
      final shortName = trimmed.contains('.')
          ? trimmed.split('.').last.trim()
          : trimmed;

      if (knownSet.contains(shortName)) {
        return shortName;
      }
      return null;
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final m = pattern.firstMatch(line);
      if (m != null && m.groupCount >= 5) {
        try {
          final x = double.parse(m.group(1)!);
          final y = double.parse(m.group(2)!);
          final angDeg = double.parse(m.group(3)!);
          final tol = double.parse(m.group(4)!);
          final tolDeg = double.parse(m.group(5)!);

          final controllerName =
              resolveName(m.group(6), knownControllers);
          final headingName =
              resolveName(m.group(7), knownHeadings);

          waypoints.add(
            Waypoint(
              anchor: Translation2d(x, y),
              holonomicAngle: Rotation2d.fromDegrees(angDeg),
              tolerance: tol,
              toleranceDeg: tolDeg,
              controllerSettings: controllerName != null
                  ? NamedControllerSettings(name: controllerName)
                  : null,
              headingStrat: headingName != null
                  ? NamedHeadingStrat(name: headingName)
                  : null,
            ),
          );
        } catch (e) {
          Log.warning('Failed to parse waypoint line: $line -> $e');
        }
      }
    }

    return waypoints;
  }

  /// Parse named ControllerSettings items from Java constants or ProfiledPIDSettings blocks.
  static List<NamedItem> importFromJavaControllers(String input) {
    final results = <NamedItem>[];
    final seen = <String>{};

    // Match ProfiledPIDSettings variable names (legacy format)
    final legacyBlockPattern = RegExp(
      r'public\s+static\s+(?:final\s+)?ProfiledPIDSettings\s+([A-Za-z0-9_]+)',
      caseSensitive: false,
    );
    for (final m in legacyBlockPattern.allMatches(input)) {
      final name = m.group(1)?.trim() ?? '';
      if (name.isNotEmpty && seen.add(name)) {
        results.add(NamedItem(name: name));
      }
    }

    // Match String constants exported by the updated format
    final stringConstPattern = RegExp(
      r'public\s+static\s+final\s+String\s+([A-Za-z0-9_]+)\s*=\s*"([^"]*)"\s*;',
    );
    for (final m in stringConstPattern.allMatches(input)) {
      final varName = m.group(1) ?? '';
      final literal = (m.group(2) ?? '').trim();
      if (!varName.toLowerCase().contains('heading') &&
          literal.isNotEmpty &&
          seen.add(literal)) {
        results.add(NamedItem(name: literal));
      }
    }

    return results;
  }

  /// Parse named HeadingStrats items from Java String constants.
  static List<NamedItem> importFromJavaHeadingStrats(String input) {
    final results = <NamedItem>[];
    final seen = <String>{};

    final stringConstPattern = RegExp(
      r'public\s+static\s+final\s+String\s+([A-Za-z0-9_]+)\s*=\s*"([^"]*)"\s*;',
    );
    for (final m in stringConstPattern.allMatches(input)) {
      final varName = m.group(1) ?? '';
      final literal = (m.group(2) ?? '').trim();
      if (varName.toLowerCase().contains('heading') &&
          literal.isNotEmpty &&
          seen.add(literal)) {
        results.add(NamedItem(name: literal));
      }
    }

    return results;
  }

  static Map<String, String> _extractStringConstants(String input) {
    final map = <String, String>{};
    final pattern = RegExp(
      r'public\s+static\s+final\s+String\s+([A-Za-z0-9_]+)\s*=\s*"([^"]*)"\s*;',
    );
    for (final m in pattern.allMatches(input)) {
      final key = m.group(1);
      final val = m.group(2);
      if (key != null && val != null) {
        map[key] = val;
      }
    }
    return map;
  }
}