import 'dart:async';

import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/physics_sim_service.dart';

class SaveService {
  static Future<String> exportToCustomFormat(
    List<Waypoint> waypoints,
  ) async {
    Log.info(
      'Custom export hook invoked with ${waypoints.length} waypoints.',
    );

    // Helper to create a safe java variable name from controller name
    String toVarName(String input) {
      if (input.trim().isEmpty) return 'settingPID';

      // remove non-alphanumeric, split on spaces/underscores/dashes
      final parts = input
          .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();

      if (parts.isEmpty) return 'settingPID';

      final camel = parts
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join();

      var res = camel[0].toLowerCase() + camel.substring(1);

      // Prevent invalid java identifiers starting with numbers
      if (RegExp(r'^[0-9]').hasMatch(res)) {
        res = '_$res';
      }

      return '${res}PID';
    }

    final usedNames = <String>{};

    String uniqueVarName(String input) {
      final base = toVarName(input);

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

    // Write controllers
    final settings = ControllerSettingsStore.settings;
    final idToVar = <String, String>{};

    for (final s in settings) {
      final varName = uniqueVarName(
        s.name.isEmpty ? 'setting${s.id}' : s.name,
      );

      idToVar[s.id] = varName;

      sb.writeln(
        'public static ProfiledPIDSettings $varName = new ProfiledPIDSettings() {{',
      );

      sb.writeln(
        '      x_kP = new SyncedNumber(${_formatNum(s.kp)});',
      );
      sb.writeln(
        '      x_kI = new SyncedNumber(${_formatNum(s.ki)});',
      );
      sb.writeln(
        '      x_kD = new SyncedNumber(${_formatNum(s.kd)});',
      );

      sb.writeln();

      sb.writeln(
        '      y_kP = new SyncedNumber(${_formatNum(s.kp)});',
      );
      sb.writeln(
        '      y_kI = new SyncedNumber(${_formatNum(s.ki)});',
      );
      sb.writeln(
        '      y_kD = new SyncedNumber(${_formatNum(s.kd)});',
      );

      sb.writeln();

      sb.writeln(
        '      rotation_kP = new SyncedNumber(${_formatNum(s.angularKp)});',
      );
      sb.writeln(
        '      rotation_kI = new SyncedNumber(${_formatNum(s.angularKi)});',
      );
      sb.writeln(
        '      rotation_kD = new SyncedNumber(${_formatNum(s.angularKd)});',
      );

      sb.writeln();

      sb.writeln(
        '      x_motionCruiseVelocity = new SyncedNumber(${_formatNum(s.cruiseVelocity)});',
      );
      sb.writeln(
        '      x_motionAcceleration = new SyncedNumber(${_formatNum(s.maxAcceleration)});',
      );

      sb.writeln();

      sb.writeln(
        '      y_motionCruiseVelocity = new SyncedNumber(${_formatNum(s.cruiseVelocity)});',
      );
      sb.writeln(
        '      y_motionAcceleration = new SyncedNumber(${_formatNum(s.maxAcceleration)});',
      );

      sb.writeln();

      sb.writeln(
        '      rotation_motionAcceleration = new SyncedNumber(${_formatNum(s.angularMaxAcceleration)});',
      );
      sb.writeln(
        '      rotation_motionCruiseVelocity = new SyncedNumber(${_formatNum(s.angularMaxVelocity)});',
      );

      sb.writeln('    }};');
      sb.writeln();
    }

    // Write waypoints as a Java ArrayList
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

      if (w.controllerSettingId != null &&
          idToVar.containsKey(w.controllerSettingId)) {
        controllerRef = idToVar[w.controllerSettingId]!;
      } else {
        // fallback to first controller if available
        if (settings.isNotEmpty) {
          controllerRef = idToVar[settings.first.id]!;
        }
      }

      sb.writeln(
        '        add(new Waypoint(new Pose2d($x, $y, new Rotation2d(Math.toRadians($angleDeg))), $tolerance, $rotationTolerance, $controllerRef));',
      );
    }

    sb.writeln('    }};');

    return sb.toString();
  }

  static String _formatNum(num? n) {
    if (n == null) return '0';

    if (n is int) return n.toString();

    final d = n.toDouble();

    if (d == d.roundToDouble()) {
      return d.round().toString();
    }

    return d.toString();
  }
}