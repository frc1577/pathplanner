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

class ModuleState {
  double angle;         // Radians
  double velocity;      // Meters per Second
  double steerVelocity; // Radians per Second

  ModuleState(this.angle, this.velocity, this.steerVelocity);
}

class PhysicsSimService {
  // --- LINEAR DRIVE MOTOR CONSTANTS (Directly from driveGains) ---
  static const double kSDrive = 0.18483;  // Volts to overcome static friction
  static const double kVDrive = 0.12462;  // Volts per meter/second
  static const double kADrive = 0.01430;  // Volts per meter/second^2
  static const double driveKP = 0.18945;  // Volts per meter/second error

  // --- AZIMUTH STEER MOTOR CONSTANTS (Converted from Rotations to Radians) ---
  static const double kSSteer = 0.23000;
  static const double kVSteer = 2.53060 / (2 * pi);  
  static const double kASteer = 0.046861 / (2 * pi); 
  static const double steerKP = 56.25800 / (2 * pi); 
  static const double steerKD = 3.34950 / (2 * pi);  

  static const double maxVoltage = 12.0; 

  // Module Layout Coordinates converted from Inches to Meters (Inches * 0.0254)
  static const List<Translation2d> moduleOffsets = [
    Translation2d(9.18602362205 * 0.0254, 12.8868110236 * 0.0254),   // Front Left
    Translation2d(9.18602362205 * 0.0254, -12.8868110236 * 0.0254),  // Front Right
    Translation2d(-9.18602362205 * 0.0254, 12.8868110236 * 0.0254),  // Back Left
    Translation2d(-9.18602362205 * 0.0254, -12.8868110236 * 0.0254), // Back Right
  ];

  /// Simulates open-loop trajectory generation tracking using 4-Module Kinematic Projection
  static PhysicsSimulationResult simulatePath(PathPlannerPath path,
      {double dt = _defaultDt}) {
    if (path.waypoints.length < 2) {
      return const PhysicsSimulationResult([]);
    }

    List<PhysicsSimState> states = [];
    num time = 0.0;

    double x = path.waypoints.first.anchor.x.toDouble();
    double y = path.waypoints.first.anchor.y.toDouble();
    double theta = path.waypoints.first.holonomicAngle.radians.toDouble();
    double vx = 0.0;
    double vy = 0.0;
    double omega = 0.0;

    List<ModuleState> modules = List.generate(4, (_) => ModuleState(theta, 0.0, 0.0));

    states.add(PhysicsSimState(
      timeSeconds: time,
      pose: Pose2d(Translation2d(x, y), Rotation2d.fromRadians(theta)),
      velocity: 0.0,
      angularVelocity: 0.0,
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

      final num cruiseVelocity = max(0.0, startSettings?.cruiseVelocity ?? 2.0);
      final num maxAccel = max(1e-6, startSettings?.maxAcceleration ?? 1.0);
      final num tolerance = max(0.0, end.tolerance);
      final num rotToleranceDeg = max(0.0, end.toleranceDeg);
      final double rotToleranceRad = (rotToleranceDeg * pi / 180.0).toDouble();

      final Rotation2d targetHeading = end.holonomicAngle;
      int steps = 0;

      while (true) {
        double currentDistanceToEnd = sqrt(pow(end.anchor.x - x, 2) + pow(end.anchor.y - y, 2));
        double headingErrorAbs = _normalizeAngle(targetHeading.radians - theta).abs().toDouble();
        if (currentDistanceToEnd <= tolerance && headingErrorAbs <= rotToleranceRad) {
          break;
        }

        final num remainingDistance = max(0.0, segmentLength - sqrt(pow(x - start.anchor.x, 2) + pow(y - start.anchor.y, 2)));
        final num stopVelocity = sqrt(max(0.0, pow(cruiseVelocity, 2) + 2 * maxAccel * remainingDistance));
        final num desiredVelocity = min(cruiseVelocity, stopVelocity);

        double nextVelocity = _stepVelocity(sqrt(vx * vx + vy * vy), desiredVelocity, maxAccel, dt).toDouble();
        
        double headingError = _normalizeAngle(targetHeading.radians - theta).toDouble();
        final num headingStopVelocity = sqrt(max(0.0, 2 * maxAccel * headingError.abs()));
        final num desiredHeadingVelocity = min(cruiseVelocity, headingStopVelocity);
        double nextAngularVelocity = _stepVelocity(omega, desiredHeadingVelocity * headingError.sign, maxAccel, dt).toDouble();

        double targetFieldVx = nextVelocity * direction.x;
        double targetFieldVy = nextVelocity * direction.y;
        double robotVx = targetFieldVx * cos(theta) + targetFieldVy * sin(theta);
        double robotVy = -targetFieldVx * sin(theta) + targetFieldVy * cos(theta);

        // 1. INVERSE KINEMATICS
        List<ModuleState> targetModuleStates = [];
        for (int m = 0; m < 4; m++) {
          double rotVx = -nextAngularVelocity * moduleOffsets[m].y;
          double rotVy = nextAngularVelocity * moduleOffsets[m].x;

          double moduleVx = robotVx + rotVx;
          double moduleVy = robotVy + rotVy;

          double speed = sqrt(moduleVx * moduleVx + moduleVy * moduleVy);
          double angle = speed > 1e-4 ? atan2(moduleVy, moduleVx) : modules[m].angle;
          targetModuleStates.add(ModuleState(angle, speed, 0.0));
        }

        // 2. WHEEL HEDING OPTIMIZATION (Run once per frame to eliminate direction flip loops)
        for (int m = 0; m < 4; m++) {
          double angleError = _normalizeAngle(targetModuleStates[m].angle - modules[m].angle).toDouble();
          if (angleError.abs() > pi / 2) {
            targetModuleStates[m].angle = _normalizeAngle(targetModuleStates[m].angle + pi).toDouble();
            targetModuleStates[m].velocity *= -1;
          }
        }

        // 3. HIGH-FREQUENCY SUB-STEPPING (Simulates 1kHz internal Talon FX processor loops)
        const int subSteps = 20;
        const double subDt = _defaultDt / subSteps;

        for (int step = 0; step < subSteps; step++) {
          for (int m = 0; m < 4; m++) {
            // Steer Controller Loop
            double subAngleError = _normalizeAngle(targetModuleStates[m].angle - modules[m].angle).toDouble();
            double steerVolts = (subAngleError * steerKP) + (0.0 - modules[m].steerVelocity) * steerKD + (kSSteer * subAngleError.sign);
            steerVolts = steerVolts.clamp(-maxVoltage, maxVoltage);

            double steerAlpha = (steerVolts - (kSSteer * modules[m].steerVelocity.sign) - (kVSteer * modules[m].steerVelocity)) / kASteer;
            modules[m].angle += modules[m].steerVelocity * subDt + 0.5 * steerAlpha * subDt * subDt;
            modules[m].steerVelocity += steerAlpha * subDt;
            modules[m].angle = _normalizeAngle(modules[m].angle).toDouble();

            // Drive Controller Loop
            double driveVolts = (targetModuleStates[m].velocity * kVDrive) + (kSDrive * targetModuleStates[m].velocity.sign) + (targetModuleStates[m].velocity - modules[m].velocity) * driveKP;
            driveVolts = driveVolts.clamp(-maxVoltage, maxVoltage);

            double driveAx = (driveVolts - (kSDrive * modules[m].velocity.sign) - (kVDrive * modules[m].velocity)) / kADrive;
            modules[m].velocity += driveAx * subDt;
          }
        }

        // 4. FORWARD KINEMATICS
        double netRobotVx = 0.0;
        double netRobotVy = 0.0;
        double netOmegaSum = 0.0;

        for (int m = 0; m < 4; m++) {
          double modVx = modules[m].velocity * cos(modules[m].angle);
          double modVy = modules[m].velocity * sin(modules[m].angle);

          netRobotVx += modVx;
          netRobotVy += modVy;

          num rX = moduleOffsets[m].x;
          num rY = moduleOffsets[m].y;
          netOmegaSum += (rX * modVy) - (rY * modVx);
        }

        netRobotVx /= 4.0;
        netRobotVy /= 4.0;
        double radiusSqSum = moduleOffsets.fold(0.0, (sum, item) => sum + (item.norm * item.norm));
        omega = netOmegaSum / radiusSqSum;

        vx = netRobotVx * cos(theta) - netRobotVy * sin(theta);
        vy = netRobotVx * sin(theta) + netRobotVy * cos(theta);

        x += vx * dt;
        y += vy * dt;
        theta += omega * dt;
        theta = _normalizeAngle(theta).toDouble();

        time += dt;

        states.add(PhysicsSimState(
          timeSeconds: time,
          pose: Pose2d(Translation2d(x, y), Rotation2d.fromRadians(theta)),
          velocity: sqrt(vx * vx + vy * vy),
          angularVelocity: omega,
        ));

        steps += 1;
        if (steps > 20000) {
          break;
        }
      }
    }

    return PhysicsSimulationResult(states);
  }

  /// Simulates closed-loop tracking with controllers feeding corrective efforts into the 4-Module Kinematic Plant
  static PhysicsSimulationResult generateSimulatedPath(PathPlannerPath path,
      {double dt = _defaultDt, double maxAcceleration = 2.0}) {
    if (path.waypoints.length < 2) {
      return const PhysicsSimulationResult([]);
    }

    List<PhysicsSimState> simulatedPath = [];
    num time = 0.0;
    
    double x = path.waypoints.first.anchor.x.toDouble();
    double y = path.waypoints.first.anchor.y.toDouble();
    double theta = path.waypoints.first.holonomicAngle.radians.toDouble();
    double vx = 0.0;
    double vy = 0.0;
    double omega = 0.0;

    List<ModuleState> modules = List.generate(4, (_) => ModuleState(theta, 0.0, 0.0));

    final Waypoint first = path.waypoints.first;

    simulatedPath.add(PhysicsSimState(
      timeSeconds: time,
      pose: Pose2d(Translation2d(x, y), Rotation2d.fromRadians(theta)),
      velocity: 0.0,
      angularVelocity: 0.0,
    ));

    ProfiledPIDController rotationalController = ProfiledPIDController(
      5, 0, 0, Constraints(3.0, maxAcceleration),
    );

    final ControllerSetting? controllerSettings = _getControllerSettingsById(path, first.controllerSettingId);

    ProfiledPIDController xController = ProfiledPIDController(
      controllerSettings?.kp ?? first.kp.toDouble(),
      controllerSettings?.ki ?? first.ki.toDouble(),
      controllerSettings?.kd ?? first.kd.toDouble(),
      Constraints(
        controllerSettings?.cruiseVelocity ?? 2.0,
        controllerSettings?.maxAcceleration ?? 1.0,
      ),
    );
    ProfiledPIDController yController = ProfiledPIDController(
      controllerSettings?.kp ?? first.kp.toDouble(),
      controllerSettings?.ki ?? first.ki.toDouble(),
      controllerSettings?.kd ?? first.kd.toDouble(),
      Constraints(
        controllerSettings?.cruiseVelocity ?? 2.0,
        controllerSettings?.maxAcceleration ?? 1.0,
      ),
    );

    xController.reset(State(x, 0.0));
    yController.reset(State(y, 0.0));
    rotationalController.reset(State(theta, 0.0));

    xController.setGoal(State(x, 0.0));
    yController.setGoal(State(y, 0.0));

    for (int i = 0; i < path.waypoints.length - 1; i++) {
      final Waypoint end = path.waypoints[i + 1];
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
        currentSettings?.cruiseVelocity ?? 2.0,
        currentSettings?.maxAcceleration ?? 1.0,
      ));
      yController.setConstraints(Constraints(
        currentSettings?.cruiseVelocity ?? 2.0,
        currentSettings?.maxAcceleration ?? 1.0,
      ));
      rotationalController.setConstraints(Constraints(
        currentSettings?.angularMaxVelocity ?? 3.0,
        currentSettings?.angularMaxAcceleration ?? 2.0,
      ));

      xController.setGoal(State(end.anchor.x.toDouble(), 0.0));
      yController.setGoal(State(end.anchor.y.toDouble(), 0.0));
      rotationalController.setGoal(State(end.holonomicAngle.radians.toDouble(), 0.0));

  final num rotToleranceDeg2 = max(0.0, end.toleranceDeg);
  final double rotToleranceRad2 = (rotToleranceDeg2 * pi / 180.0).toDouble();

  while (sqrt(pow(end.anchor.x - x, 2) + pow(end.anchor.y - y, 2)) > end.tolerance || (_normalizeAngle(end.holonomicAngle.radians - theta).abs().toDouble() > rotToleranceRad2)) {
        double targetVx = xController.calculate(x);
        double targetVy = yController.calculate(y);
        double targetOmega = rotationalController.calculate(theta);

        double robotVx = targetVx * cos(theta) + targetVy * sin(theta);
        double robotVy = -targetVx * sin(theta) + targetVy * cos(theta);

        // 1. INVERSE KINEMATICS
        List<ModuleState> targetModuleStates = [];
        for (int m = 0; m < 4; m++) {
          double rotVx = -targetOmega * moduleOffsets[m].y;
          double rotVy = targetOmega * moduleOffsets[m].x;

          double moduleVx = robotVx + rotVx;
          double moduleVy = robotVy + rotVy;

          double speed = sqrt(moduleVx * moduleVx + moduleVy * moduleVy);
          double angle = speed > 1e-4 ? atan2(moduleVy, moduleVx) : modules[m].angle;
          targetModuleStates.add(ModuleState(angle, speed, 0.0));
        }

        // 2. WHEEL HEADING OPTIMIZATION
        for (int m = 0; m < 4; m++) {
          double angleError = _normalizeAngle(targetModuleStates[m].angle - modules[m].angle).toDouble();
          if (angleError.abs() > pi / 2) {
            targetModuleStates[m].angle = _normalizeAngle(targetModuleStates[m].angle + pi).toDouble();
            targetModuleStates[m].velocity *= -1;
          }
        }

        // 3. HIGH-FREQUENCY SUB-STEPPING
        const int subSteps = 20;
        const double subDt = _defaultDt / subSteps;

        for (int step = 0; step < subSteps; step++) {
          for (int m = 0; m < 4; m++) {
            // Steer Controller Loop
            double subAngleError = _normalizeAngle(targetModuleStates[m].angle - modules[m].angle).toDouble();
            double steerVolts = (subAngleError * steerKP) + (0.0 - modules[m].steerVelocity) * steerKD + (kSSteer * subAngleError.sign);
            steerVolts = steerVolts.clamp(-maxVoltage, maxVoltage);

            double steerAlpha = (steerVolts - (kSSteer * modules[m].steerVelocity.sign) - (kVSteer * modules[m].steerVelocity)) / kASteer;
            modules[m].angle += modules[m].steerVelocity * subDt + 0.5 * steerAlpha * subDt * subDt;
            modules[m].steerVelocity += steerAlpha * subDt;
            modules[m].angle = _normalizeAngle(modules[m].angle).toDouble();

            // Drive Controller Loop
            double driveVolts = (targetModuleStates[m].velocity * kVDrive) + (kSDrive * targetModuleStates[m].velocity.sign) + (targetModuleStates[m].velocity - modules[m].velocity) * driveKP;
            driveVolts = driveVolts.clamp(-maxVoltage, maxVoltage);

            double driveAx = (driveVolts - (kSDrive * modules[m].velocity.sign) - (kVDrive * modules[m].velocity)) / kADrive;
            modules[m].velocity += driveAx * subDt;
          }
        }

        // 4. FORWARD KINEMATICS
        double netRobotVx = 0.0;
        double netRobotVy = 0.0;
        double netOmegaSum = 0.0;

        for (int m = 0; m < 4; m++) {
          double modVx = modules[m].velocity * cos(modules[m].angle);
          double modVy = modules[m].velocity * sin(modules[m].angle);

          netRobotVx += modVx;
          netRobotVy += modVy;

          num rX = moduleOffsets[m].x;
          num rY = moduleOffsets[m].y;
          netOmegaSum += (rX * modVy) - (rY * modVx);
        }

        netRobotVx /= 4.0;
        netRobotVy /= 4.0;
        double radiusSqSum = moduleOffsets.fold(0.0, (sum, item) => sum + (item.norm * item.norm));
        omega = netOmegaSum / radiusSqSum;

        vx = netRobotVx * cos(theta) - netRobotVy * sin(theta);
        vy = netRobotVx * sin(theta) + netRobotVy * cos(theta);

        x += vx * dt;
        y += vy * dt;
        theta += omega * dt;
        theta = _normalizeAngle(theta).toDouble();

        time += dt;

        simulatedPath.add(PhysicsSimState(
          timeSeconds: time,
          pose: Pose2d(Translation2d(x, y), Rotation2d.fromRadians(theta)),
          velocity: sqrt(vx * vx + vy * vy),
          angularVelocity: omega,
        ));

        if (simulatedPath.length > 20000) {
          break;
        }
      }
    }

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

    for (final s in ControllerSettingsStore.settings) {
      if (s.id == id) return s;
    }

    return null;
  }
}

class ControllerSettingsStore {
  static List<ControllerSetting> _settings = _defaultSettings();

  static List<ControllerSetting> get settings => List.unmodifiable(_settings);

  static void setSettings(List<ControllerSetting> settings) {
    _settings = List.of(settings);
  }

  static void loadFromJson(dynamic json) {
    if (json is List) {
      final parsed = <ControllerSetting>[];
      for (final entry in json) {
        if (entry is Map<String, dynamic>) {
          parsed.add(ControllerSetting.fromJson(entry));
        } else if (entry is Map) {
          parsed.add(ControllerSetting.fromJson(
              entry.map((key, value) => MapEntry(key.toString(), value))));
        }
      }

      _settings = parsed;
      return;
    }

    _settings = _defaultSettings();
  }

  static List<Map<String, dynamic>> toJson() {
    return [for (final setting in _settings) setting.toJson()];
  }

  static List<ControllerSetting> _defaultSettings() {
    return [
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

  factory ControllerSetting.fromJson(Map<String, dynamic> json) {
    double readDouble(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    return ControllerSetting(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      kp: readDouble(json['kp'], 0.0),
      ki: readDouble(json['ki'], 0.0),
      kd: readDouble(json['kd'], 0.0),
      cruiseVelocity: readDouble(json['cruiseVelocity'], 0.0),
      maxAcceleration: readDouble(json['maxAcceleration'], 0.0),
      angularKp: readDouble(json['angularKp'], 0.0),
      angularKi: readDouble(json['angularKi'], 0.0),
      angularKd: readDouble(json['angularKd'], 0.0),
      angularMaxVelocity: readDouble(json['angularMaxVelocity'], 0.0),
      angularMaxAcceleration: readDouble(json['angularMaxAcceleration'], 0.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'kp': kp,
      'ki': ki,
      'kd': kd,
      'cruiseVelocity': cruiseVelocity,
      'maxAcceleration': maxAcceleration,
      'angularKp': angularKp,
      'angularKi': angularKi,
      'angularKd': angularKd,
      'angularMaxVelocity': angularMaxVelocity,
      'angularMaxAcceleration': angularMaxAcceleration,
    };
  }
}