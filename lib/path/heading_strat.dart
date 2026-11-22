import 'package:pathplanner/util/wpimath/geometry.dart';

class HeadingStratKinds {
  static const String simple = 'SimpleHeadingStrat';
  static const String faceTarget = 'FaceTargetHeadingStrat';
  static const String named = 'NamedHeadingStrat';

  static const List<String> values = [
    simple,
    faceTarget,
    named,
  ];

  static String labelFor(String kind) {
    switch (kind) {
      case simple:
        return 'Simple Heading Strat';
      case faceTarget:
        return 'Face Target Heading Strat';
      case named:
        return 'Named Heading Strat';
      default:
        return kind;
    }
  }
}

class HeadingStrat {
  String name;
  String type;
  double degrees;
  double targetX;
  double targetY;
  double offsetDeg;
  String innerType;

  HeadingStrat({
    required this.name,
    required this.type,
    required this.degrees,
    required this.targetX,
    required this.targetY,
    required this.offsetDeg,
    this.innerType = HeadingStratKinds.simple,
  });

  factory HeadingStrat.fromJson(Map<String, dynamic> json) {
    double readDouble(dynamic value, double defaultValue) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    String rawType = json['type']?.toString() ?? HeadingStratKinds.simple;
    String type = HeadingStratKinds.values.contains(rawType)
        ? rawType
        : HeadingStratKinds.simple;

    String rawInnerType =
        json['innerType']?.toString() ?? HeadingStratKinds.simple;
    String innerType = (rawInnerType == HeadingStratKinds.simple ||
            rawInnerType == HeadingStratKinds.faceTarget)
        ? rawInnerType
        : HeadingStratKinds.simple;

    return HeadingStrat(
      name: json['name']?.toString() ?? '',
      type: type,
      degrees: readDouble(json['degrees'], readDouble(json['headingDeg'], 0.0)),
      targetX: readDouble(json['targetX'], 0.0),
      targetY: readDouble(json['targetY'], 0.0),
      offsetDeg:
          readDouble(json['offsetDeg'], readDouble(json['headingDeg'], 0.0)),
      innerType: innerType,
    );
  }

  Map<String, dynamic> toJson() {
    if (type == HeadingStratKinds.named) {
      return {
        'name': name,
        'type': type,
        'innerType': innerType,
        if (innerType == HeadingStratKinds.simple) 'degrees': degrees,
        if (innerType == HeadingStratKinds.faceTarget) ...{
          'offsetDeg': offsetDeg,
          'targetX': targetX,
          'targetY': targetY,
        },
      };
    }

    if (type == HeadingStratKinds.simple) {
      return {
        'name': name,
        'type': type,
        'degrees': degrees,
      };
    }

    if (type == HeadingStratKinds.faceTarget) {
      return {
        'name': name,
        'type': type,
        'offsetDeg': offsetDeg,
        'targetX': targetX,
        'targetY': targetY,
      };
    }

    return {
      'name': name,
      'type': type,
      'degrees': degrees,
      'targetX': targetX,
      'targetY': targetY,
      'offsetDeg': offsetDeg,
      'innerType': innerType,
    };
  }

  HeadingStrat clone() {
    return HeadingStrat(
      name: name,
      type: type,
      degrees: degrees,
      targetX: targetX,
      targetY: targetY,
      offsetDeg: offsetDeg,
      innerType: innerType,
    );
  }

  bool get isSimple =>
      type == HeadingStratKinds.simple ||
      (type == HeadingStratKinds.named && innerType == HeadingStratKinds.simple);

  bool get isFaceTarget =>
      type == HeadingStratKinds.faceTarget ||
      (type == HeadingStratKinds.named &&
          innerType == HeadingStratKinds.faceTarget);

  Rotation2d? resolveHeading(Translation2d robotPose) {
    if (isFaceTarget) {
      final directionToTarget = Translation2d(targetX, targetY) - robotPose;
      return directionToTarget.angle + Rotation2d.fromDegrees(offsetDeg);
    }

    return Rotation2d.fromDegrees(degrees);
  }
}