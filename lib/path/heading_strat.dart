import 'dart:math';

import 'package:pathplanner/util/wpimath/geometry.dart';

class HeadingStratKinds {
  static const String simple = 'SimpleHeadingStrat';
  static const String simpleOnCondition = 'SimpleHeadingStratOnCondition';
  static const String faceTarget = 'FaceTargetHeadingStrat';
  static const String faceTargetOnCondition =
      'FaceTargetHeadingStratOnCondition';

  static const List<String> values = [
    simple,
    simpleOnCondition,
    faceTarget,
    faceTargetOnCondition,
  ];

  static String labelFor(String kind) {
    switch (kind) {
      case simple:
        return 'Simple Heading Strat';
      case simpleOnCondition:
        return 'Simple Heading Strat On Condition';
      case faceTarget:
        return 'Face Target Heading Strat';
      case faceTargetOnCondition:
        return 'Face Target Heading Strat On Condition';
      default:
        return kind;
    }
  }
}

class HeadingStrat {
  final String id;
  String name;
  String type;
  double degrees;
  double targetX;
  double targetY;
  double offsetDeg;
  String condition;

  HeadingStrat({
    required this.id,
    required this.name,
    required this.type,
    required this.degrees,
    required this.targetX,
    required this.targetY,
    required this.offsetDeg,
    required this.condition,
  });

  factory HeadingStrat.fromJson(Map<String, dynamic> json) {
    double readDouble(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    return HeadingStrat(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? HeadingStratKinds.simple,
      degrees: readDouble(json['degrees'], readDouble(json['headingDeg'], 0.0)),
      targetX: readDouble(json['targetX'], 0.0),
      targetY: readDouble(json['targetY'], 0.0),
      offsetDeg:
          readDouble(json['offsetDeg'], readDouble(json['headingDeg'], 0.0)),
      condition: json['condition']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'degrees': degrees,
      'targetX': targetX,
      'targetY': targetY,
      'offsetDeg': offsetDeg,
      'condition': condition,
    };
  }

  HeadingStrat clone() {
    return HeadingStrat(
      id: id,
      name: name,
      type: type,
      degrees: degrees,
      targetX: targetX,
      targetY: targetY,
      offsetDeg: offsetDeg,
      condition: condition,
    );
  }

  bool get isSimple =>
      type == HeadingStratKinds.simple ||
      type == HeadingStratKinds.simpleOnCondition;

  bool get isFaceTarget =>
      type == HeadingStratKinds.faceTarget ||
      type == HeadingStratKinds.faceTargetOnCondition;

  Rotation2d resolveHeading(Translation2d robotPose) {
    if (isFaceTarget) {
      final directionToTarget = Translation2d(targetX, targetY) - robotPose;
      return directionToTarget.angle + Rotation2d.fromDegrees(offsetDeg);
    }

    return Rotation2d.fromDegrees(degrees);
  }
}
