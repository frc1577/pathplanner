import 'dart:math';

import 'package:pathplanner/controllers/profiled_pid_controller.dart';
import 'package:pathplanner/path/pathplanner_path.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

const double _defaultDt = 0.02;

class PhysicsSimState {
  final num timeSeconds;
  final Pose2d pose;
  final num velocity;
  final num angularVelocity;

  const PhysicsSimState({
    required this.timeSeconds,
    required this.pose,
    required this.velocity,
    required this.angularVelocity,
  });

  PhysicsSimState lerp(PhysicsSimState other, double t) {
    return PhysicsSimState(
      timeSeconds: timeSeconds + (other.timeSeconds - timeSeconds) * t,
      pose: Pose2d(
        pose.translation.interpolate(other.pose.translation, t),
        pose.rotation.interpolate(other.pose.rotation, t),
      ),
      velocity: velocity + (other.velocity - velocity) * t,
      angularVelocity:
          angularVelocity + (other.angularVelocity - angularVelocity) * t,
    );
  }
}

class PhysicsSimulationResult {
  final List<PhysicsSimState> states;

  const PhysicsSimulationResult(this.states);

  num get totalTimeSeconds =>
      states.isEmpty ? 0.0 : states.last.timeSeconds;

  PhysicsSimState sample(num timeSeconds) {
    if (states.isEmpty) {
      return const PhysicsSimState(
        timeSeconds: 0.0,
        pose: Pose2d(Translation2d(0, 0), Rotation2d()),
        velocity: 0.0,
        angularVelocity: 0.0,
      );
    }

    if (timeSeconds <= states.first.timeSeconds) {
      return states.first;
    }
    if (timeSeconds >= states.last.timeSeconds) {
      return states.last;
    }

    for (int i = 0; i < states.length - 1; i++) {
      if (timeSeconds >= states[i].timeSeconds &&
          timeSeconds <= states[i + 1].timeSeconds) {
        final span = states[i + 1].timeSeconds - states[i].timeSeconds;
        final t = span == 0 ? 0.0 : (timeSeconds - states[i].timeSeconds) / span;
        return states[i].lerp(states[i + 1], t.toDouble());
      }
    }

    return states.last;
  }
}

class PhysicsSimService {
  static PhysicsSimulationResult simulatePath(PathPlannerPath path,
      {double dt = _defaultDt}) {
    if (path.waypoints.length < 2) {
      return const PhysicsSimulationResult([]);
    }

    List<PhysicsSimState> states = [];
    num time = 0.0;
    num currentVelocity = 0.0;
    num currentAngularVelocity = 0.0;
    Rotation2d currentHeading = path.waypoints.first.holonomicAngle;
    Translation2d currentPos = path.waypoints.first.anchor;

    states.add(PhysicsSimState(
      timeSeconds: time,
      pose: Pose2d(currentPos, currentHeading),
      velocity: currentVelocity,
      angularVelocity: currentAngularVelocity,
    ));

    for (int i = 0; i < path.waypoints.length - 1; i++) {
      final Waypoint start = path.waypoints[i];
      final Waypoint end = path.waypoints[i + 1];

      final Translation2d segmentVector = end.anchor - start.anchor;
      final num segmentLength = segmentVector.norm;
      if (segmentLength <= 1e-6) {
        continue;
      }

      final Translation2d direction =
          Translation2d(segmentVector.x / segmentLength, segmentVector.y / segmentLength);

  final ControllerSetting? startSettings = _getControllerSettingsById(path, start.controllerSettingId);

      final num cruiseVelocity = max(0.0, startSettings?.cruiseVelocity ?? 0.0);
      final num maxAccel = max(1e-6, startSettings?.maxAcceleration ?? 1e-6);
      final num tolerance = max(0.0, end.tolerance);

      final Rotation2d targetHeading = end.holonomicAngle;
      num headingError = _normalizeAngle(targetHeading.radians - currentHeading.radians);

      num distanceAlong = 0.0;
      int steps = 0;
      while (true) {
        final num remainingDistance = max(0.0, segmentLength - distanceAlong);
        final num stopVelocity = sqrt(
            max(0.0, pow(cruiseVelocity, 2) + 2 * maxAccel * remainingDistance));
        final num desiredVelocity = min(cruiseVelocity, stopVelocity);

        currentVelocity =
            _stepVelocity(currentVelocity, desiredVelocity, maxAccel, dt);
        final num previousDistance = (segmentLength - distanceAlong).abs();
        distanceAlong = distanceAlong + currentVelocity * dt;
        currentPos = start.anchor + (direction * distanceAlong);

        final num remainingHeading = headingError.abs();
        final num headingStopVelocity =
            sqrt(max(0.0, 2 * maxAccel * remainingHeading));
        final num desiredHeadingVelocity =
            min(cruiseVelocity, headingStopVelocity);
        currentAngularVelocity = _stepVelocity(
            currentAngularVelocity, desiredHeadingVelocity * headingError.sign, maxAccel, dt);
        final num headingStep = currentAngularVelocity * dt;
        currentHeading = Rotation2d.fromRadians(
            currentHeading.radians + headingStep);
        headingError = _normalizeAngle(targetHeading.radians - currentHeading.radians);

        time += dt;
        states.add(PhysicsSimState(
          timeSeconds: time,
          pose: Pose2d(currentPos, currentHeading),
          velocity: currentVelocity,
          angularVelocity: currentAngularVelocity,
        ));

        final num currentDistance = (segmentLength - distanceAlong).abs();
        if (min(previousDistance, currentDistance) <= tolerance ||
            (currentDistance <= tolerance + 1e-6 &&
                currentVelocity <= 1e-3)) {
          break;
        }

        steps += 1;
        if (steps > 20000) {
          break;
        }
      }
    }

    return PhysicsSimulationResult(states);
  }

  static PhysicsSimulationResult generateSimulatedPath(PathPlannerPath path,
      {double dt = _defaultDt, double maxAcceleration = 2.0}) {
    if (path.waypoints.length < 2) {
      return const PhysicsSimulationResult([]);
    }

    List<PhysicsSimState> simulatedPath = [];
    num time = 0.0;
    num currentVelocity = 0.0;
    num currentAngularVelocity = 0.0;
    final Waypoint first = path.waypoints.first;
    Rotation2d currentHeading = first.holonomicAngle;
    Translation2d currentPos = first.anchor;

    ProfiledPIDController rotationalController = ProfiledPIDController(
      5, 0, 0, Constraints(3.0, maxAcceleration),
    );

  // Fetch the controller settings for the first waypoint (prefer path-registered settings)
  final ControllerSetting? controllerSettings = _getControllerSettingsById(path, first.controllerSettingId);

    ProfiledPIDController xController = ProfiledPIDController(
      controllerSettings?.kp ?? first.kp.toDouble(),
      controllerSettings?.ki ?? first.ki.toDouble(),
      controllerSettings?.kd ?? first.kd.toDouble(),
      Constraints(
        controllerSettings?.cruiseVelocity ?? 0.0,
        controllerSettings?.maxAcceleration ?? 1e-6,
      ),
    );
    ProfiledPIDController yController = ProfiledPIDController(
      controllerSettings?.kp ?? first.kp.toDouble(),
      controllerSettings?.ki ?? first.ki.toDouble(),
      controllerSettings?.kd ?? first.kd.toDouble(),
      Constraints(
        controllerSettings?.cruiseVelocity ?? 0.0,
        controllerSettings?.maxAcceleration ?? 1e-6,
      ),
    );

    xController.reset(State(first.anchor.x.toDouble(), 0.0));
    yController.reset(State(first.anchor.y.toDouble(), 0.0));

    rotationalController.reset(
        State(first.holonomicAngle.radians.toDouble(), 0.0));

    // Set the initial goal of the controllers to the start point (first waypoint)
    xController.setGoal(State(first.anchor.x.toDouble(), 0.0));
    yController.setGoal(State(first.anchor.y.toDouble(), 0.0));

    print('Starting generateSimulatedPath with ${path.waypoints.length} waypoints');

    for (int i = 0; i < path.waypoints.length - 1; i++) {
      final Waypoint end = path.waypoints[i + 1];

  // Fetch the controller settings dynamically for the current waypoint (prefer path-registered settings)
  final ControllerSetting? currentSettings = _getControllerSettingsById(path, end.controllerSettingId);

      xController.setPID(
        currentSettings?.kp ?? end.kp.toDouble(),
        currentSettings?.ki ?? end.ki.toDouble(),
        currentSettings?.kd ?? end.kd.toDouble(),
      );
      yController.setPID(
        currentSettings?.kp ?? end.kp.toDouble(),
        currentSettings?.ki ?? end.ki.toDouble(),
        currentSettings?.kd ?? end.kd.toDouble(),
      );
      rotationalController.setPID(
        currentSettings?.angularKp ?? 5.0,
        currentSettings?.angularKi ?? 0.0,
        currentSettings?.angularKd ?? 0.0,
      );

      xController.setConstraints(Constraints(
        currentSettings?.cruiseVelocity ?? 0.0,
        currentSettings?.maxAcceleration ?? 1e-6,
      ));
      yController.setConstraints(Constraints(
        currentSettings?.cruiseVelocity ?? 0.0,
        currentSettings?.maxAcceleration ?? 1e-6,
      ));
      rotationalController.setConstraints(Constraints(
        currentSettings?.angularMaxVelocity ?? 3.0,
        currentSettings?.angularMaxAcceleration ?? 2.0,
      ));

      xController.setGoal(State(end.anchor.x.toDouble(), 0.0));
      yController.setGoal(State(end.anchor.y.toDouble(), 0.0));
      rotationalController.setGoal(State(end.holonomicAngle.radians.toDouble(), 0.0));

      while ((currentPos - end.anchor).norm > end.tolerance) {
        final double xOutput = xController.calculate(currentPos.x.toDouble());
        final double yOutput = yController.calculate(currentPos.y.toDouble());
        final double rotationalOutput =
            rotationalController.calculate(currentHeading.radians.toDouble());

        final double targetLinearVelocity =
            sqrt(pow(xOutput, 2) + pow(yOutput, 2)).toDouble();

    final double linearDelta =
      (targetLinearVelocity - currentVelocity.toDouble())
        .clamp(-xController.getConstraints().maxAcceleration * dt, xController.getConstraints().maxAcceleration * dt);

        currentVelocity += linearDelta;

    final double angularDelta =
      (rotationalOutput - currentAngularVelocity.toDouble())
        .clamp(-rotationalController.getConstraints().maxAcceleration * dt, rotationalController.getConstraints().maxAcceleration * dt);

        currentAngularVelocity += angularDelta;
        currentPos += Translation2d(xOutput * dt, yOutput * dt);
        currentHeading = Rotation2d(currentHeading.radians +
            currentAngularVelocity * dt);

        time += dt;

        simulatedPath.add(PhysicsSimState(
          timeSeconds: time,
          pose: Pose2d(currentPos, currentHeading),
          velocity: currentVelocity,
          angularVelocity: currentAngularVelocity,
        ));

        if (simulatedPath.length > 10000) {
          print('Simulation path too long, breaking early');
          break;
        }
      }

      print('Waypoint $i reached: $currentPos');
    }

    print('Finished generateSimulatedPath with ${simulatedPath.length} states');

    return PhysicsSimulationResult(simulatedPath);
  }

  static num _stepVelocity(num current, num target, num maxAccel, num dt) {
    final num delta = target - current;
    final num maxDelta = maxAccel * dt;
    if (delta.abs() <= maxDelta) {
      return target;
    }
    return current + maxDelta * delta.sign;
  }

  static num _normalizeAngle(num radians) {
    num angle = radians;
    while (angle > pi) {
      angle -= 2 * pi;
    }
    while (angle < -pi) {
      angle += 2 * pi;
    }
    return angle;
  }

  static ControllerSetting? _getControllerSettingsById(PathPlannerPath path, String? id) {
    if (id == null) return null;

    // Prefer any user-registered controller settings stored on the path
    try {
      for (final s in path.controllerSettings) {
        if (s.id == id) return s;
      }
    } catch (_) {
      // If path.controllerSettings is not available for some reason, fall back to defaults below
    }

    // Fallback to built-in defaults (maintain previous behavior)
    final settings = [
      ControllerSetting(
        id: '1',
        name: 'Default Setting',
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
      ),
      ControllerSetting(
        id: '2',
        name: 'Aggressive Setting',
        kp: 2.0,
        ki: 0.5,
        kd: 0.1,
        cruiseVelocity: 3.0,
        maxAcceleration: 2.0,
        angularKp: 6.0,
        angularKi: 0.1,
        angularKd: 0.2,
        angularMaxVelocity: 4.0,
        angularMaxAcceleration: 3.0,
      ),
    ];

    return settings.firstWhere((setting) => setting.id == id,
        orElse: () => ControllerSetting(id: 'null', name: 'null', kp: 0.0, ki: 0.0, kd: 0.0, cruiseVelocity: 0, maxAcceleration: 0.0, angularKp: 0.0, angularKi: 0.0, angularKd: 0.0, angularMaxVelocity: 0.0, angularMaxAcceleration: 0.0));
  }
}

class ControllerSetting {
  final String id;
  final String name;
  final double kp;
  final double ki;
  final double kd;
  final double cruiseVelocity;
  final double maxAcceleration;
  final double angularKp;
  final double angularKi;
  final double angularKd;
  final double angularMaxVelocity;
  final double angularMaxAcceleration;

  ControllerSetting({
    required this.id,
    required this.name,
    required this.kp,
    required this.ki,
    required this.kd,
    required this.cruiseVelocity,
    required this.maxAcceleration,
    required this.angularKp,
    required this.angularKi,
    required this.angularKd,
    required this.angularMaxVelocity,
    required this.angularMaxAcceleration,
  });
}
