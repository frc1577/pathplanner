import 'dart:async';

import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/log.dart';
import 'package:pathplanner/services/physics_sim_service.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

class SaveService {
  static Future<String> exportToCustomFormat(
    List<Waypoint> waypoints,
  ) async {
    Log.info(
      'Custom export hook invoked with ${waypoints.length} waypoints.',
    );

    // Helper to create a safe java variable name from controller name
    String toVarName(String input) {
      if (input.trim().isEmpty) return 'setting';

      // remove non-alphanumeric, split on spaces/underscores/dashes
      final parts = input
          .replaceAll(RegExp(r'[^A-Za-z0-9 ]'), ' ')
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();

      if (parts.isEmpty) return 'setting';

      final camel = parts
          .map((p) => p[0].toUpperCase() + p.substring(1))
          .join();

      var res = camel[0].toLowerCase() + camel.substring(1);

      // Prevent invalid java identifiers starting with numbers
      if (RegExp(r'^[0-9]').hasMatch(res)) {
        res = '_$res';
      }

      return res;
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

      // Add @Sync annotation with the exported setting name
      sb.writeln('@Sync("$varName")');
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

  /// Parse a Java-style list of add(new Waypoint(...)) lines and return waypoints.
  ///
  /// Example supported line:
  /// add(new Waypoint(new Pose2d(3.15, 7.58, new Rotation2d(Math.toRadians(0))), 1, 360, AutoConstants.mediumPID));
  ///
  /// This will ignore AutoConstants references and instead only read the numeric
  /// values for x, y, angle (degrees), tolerance, toleranceDeg. Controller
  /// settings will be left null.
  static List<Waypoint> importFromJavaWaypoints(String input) {
    final lines = input.split(RegExp(r"\r?\n"));
    final waypoints = <Waypoint>[];

    final pattern = RegExp(
      r"add\s*\(\s*new\s+Waypoint\s*\(\s*new\s+Pose2d\s*\(\s*([0-9+\-eE.]+)\s*,\s*([0-9+\-eE.]+)\s*,\s*new\s+Rotation2d\s*\(\s*Math\.toRadians\s*\(\s*([0-9+\-eE.]+)\s*\)\s*\)\s*\)\s*,\s*([0-9+\-eE.]+)\s*,\s*([0-9+\-eE.]+)",
      caseSensitive: false,
    );

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

          final wp = Waypoint(
            anchor: Translation2d(x, y),
            holonomicAngle: Rotation2d.fromDegrees(angDeg),
            tolerance: tol,
            toleranceDeg: tolDeg,
            controllerSettingId: null,
          );

          waypoints.add(wp);
        } catch (e) {
          Log.warning('Failed to parse waypoint line: $line -> $e');
        }
      }
    }

    return waypoints;
  }

  /// Parse Java-style ProfiledPIDSettings blocks exported by this app and return
  /// a list of ControllerSetting objects.
  ///
  /// Example supported block:
  /// @Sync("intakingController")
  /// public static ProfiledPIDSettings intakingController = new ProfiledPIDSettings() {{
  ///   x_kP = new SyncedNumber(3.5);
  ///   x_kI = new SyncedNumber(0);
  ///   ...
  /// }};
  static List<ControllerSetting> importFromJavaControllers(String input) {
    final results = <ControllerSetting>[];

    // Match each ProfiledPIDSettings initializer block and capture the var name
    // and the inner body.
    final blockPattern = RegExp(
      r"public\s+static\s+ProfiledPIDSettings\s+([A-Za-z0-9_]+)\s*=\s*new\s+ProfiledPIDSettings\(\)\s*\{\{([\s\S]*?)\}\}\s*;",
      caseSensitive: false,
    );

    final assignPattern = RegExp(
      r"([A-Za-z0-9_]+)\s*=\s*(?:new\s+SyncedNumber\s*\(\s*([0-9+\-eE.]+)\s*\)|([0-9+\-eE.]+))\s*;",
      caseSensitive: false,
    );

    final defaults = ControllerSetting(
      id: '0',
      name: 'Default',
      kp: 1.0,
      ki: 0.0,
      kd: 0.0,
      cruiseVelocity: 2.0,
      maxAcceleration: 1.0,
      angularKp: 5.0,
      angularKi: 0.0,
      angularKd: 0.0,
      angularMaxVelocity: 3.0,
      angularMaxAcceleration: 2.0,
    );

    int idx = 0;
    for (final m in blockPattern.allMatches(input)) {
      final varName = m.group(1) ?? 'setting$idx';
      final body = m.group(2) ?? '';

      double? readNum(String? s) {
        if (s == null) return null;
        return double.tryParse(s);
      }

      // Temporary holders
      double? x_kP;
      double? x_kI;
      double? x_kD;
      double? y_kP;
      double? y_kI;
      double? y_kD;
      double? rotation_kP;
      double? rotation_kI;
      double? rotation_kD;
      double? x_motionCruiseVelocity;
      double? x_motionAcceleration;
      double? y_motionCruiseVelocity;
      double? y_motionAcceleration;
      double? rotation_motionAcceleration;
      double? rotation_motionCruiseVelocity;

      for (final a in assignPattern.allMatches(body)) {
        final key = a.group(1)!.trim();
        final val1 = a.group(2);
        final val2 = a.group(3);
        final numVal = readNum(val1 ?? val2);
        if (numVal == null) continue;

        switch (key) {
          case 'x_kP':
            x_kP = numVal;
            break;
          case 'x_kI':
            x_kI = numVal;
            break;
          case 'x_kD':
            x_kD = numVal;
            break;
          case 'y_kP':
            y_kP = numVal;
            break;
          case 'y_kI':
            y_kI = numVal;
            break;
          case 'y_kD':
            y_kD = numVal;
            break;
          case 'rotation_kP':
            rotation_kP = numVal;
            break;
          case 'rotation_kI':
            rotation_kI = numVal;
            break;
          case 'rotation_kD':
            rotation_kD = numVal;
            break;
          case 'x_motionCruiseVelocity':
            x_motionCruiseVelocity = numVal;
            break;
          case 'x_motionAcceleration':
            x_motionAcceleration = numVal;
            break;
          case 'y_motionCruiseVelocity':
            y_motionCruiseVelocity = numVal;
            break;
          case 'y_motionAcceleration':
            y_motionAcceleration = numVal;
            break;
          case 'rotation_motionAcceleration':
            rotation_motionAcceleration = numVal;
            break;
          case 'rotation_motionCruiseVelocity':
            rotation_motionCruiseVelocity = numVal;
            break;
        }
      }

      // Choose sensible fallbacks. Prefer x_* values, then y_*, then defaults.
      final kp = x_kP ?? y_kP ?? defaults.kp;
      final ki = x_kI ?? y_kI ?? defaults.ki;
      final kd = x_kD ?? y_kD ?? defaults.kd;
      final cruise = x_motionCruiseVelocity ?? y_motionCruiseVelocity ?? defaults.cruiseVelocity;
      final accel = x_motionAcceleration ?? y_motionAcceleration ?? defaults.maxAcceleration;
      final aKp = rotation_kP ?? defaults.angularKp;
      final aKi = rotation_kI ?? defaults.angularKi;
      final aKd = rotation_kD ?? defaults.angularKd;
      final aMaxVel = rotation_motionCruiseVelocity ?? defaults.angularMaxVelocity;
      final aMaxAccel = rotation_motionAcceleration ?? defaults.angularMaxAcceleration;

      final id = '${DateTime.now().microsecondsSinceEpoch}_$idx';

      results.add(ControllerSetting(
        id: id,
        name: varName,
        kp: kp,
        ki: ki,
        kd: kd,
        cruiseVelocity: cruise,
        maxAcceleration: accel,
        angularKp: aKp,
        angularKi: aKi,
        angularKd: aKd,
        angularMaxVelocity: aMaxVel,
        angularMaxAcceleration: aMaxAccel,
      ));

      idx += 1;
    }

    return results;
  }
}