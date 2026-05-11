import 'dart:collection';
import 'dart:math';

import 'package:pathplanner/util/wpimath/geometry.dart';

class Waypoint {
  static const num headingHandleLength = 0.5;
  static HashMap<String, Pose2d> linked = HashMap();

  Translation2d anchor;
  Rotation2d holonomicAngle;
  num cruiseVelocity;
  num maxAcceleration;
  num tolerance;
  bool isLocked;
  String? linkedName;

  bool _isAnchorDragging = false;
  bool _isHeadingDragging = false;

  Waypoint({
    required this.anchor,
    Rotation2d? holonomicAngle,
    this.cruiseVelocity = 0.0,
    this.maxAcceleration = 0.0,
    this.tolerance = 0.1,
    this.isLocked = false,
    this.linkedName,
  }) : holonomicAngle = holonomicAngle ?? const Rotation2d();

  bool get isAnchorDragging => _isAnchorDragging;

  bool get isHeadingDragging => _isHeadingDragging;

  Waypoint.fromJson(Map<String, dynamic> json)
      : this(
          anchor: Translation2d.fromJson(json['anchor']),
          holonomicAngle: _holonomicAngleFromJson(json),
          cruiseVelocity: json['cruiseVelocity'] ?? 0.0,
          maxAcceleration: json['maxAcceleration'] ?? 0.0,
          tolerance: json['tolerance'] ?? 0.1,
          isLocked: json['isLocked'] ?? false,
          linkedName: json['linkedName'],
        );

  static Rotation2d _holonomicAngleFromJson(Map<String, dynamic> json) {
    if (json['holonomicAngle'] != null) {
      return Rotation2d.fromDegrees(json['holonomicAngle'].toDouble());
    }

    if (json['nextControl'] != null) {
      final anchor = Translation2d.fromJson(json['anchor']);
      final nextControl = Translation2d.fromJson(json['nextControl']);
      return (nextControl - anchor).angle;
    }

    if (json['prevControl'] != null) {
      final anchor = Translation2d.fromJson(json['anchor']);
      final prevControl = Translation2d.fromJson(json['prevControl']);
      return (anchor - prevControl).angle;
    }

    return const Rotation2d();
  }

  Map<String, dynamic> toJson() {
    return {
      'anchor': anchor.toJson(),
      'holonomicAngle': holonomicAngle.degrees,
      'cruiseVelocity': cruiseVelocity,
      'maxAcceleration': maxAcceleration,
      'tolerance': tolerance,
      'isLocked': isLocked,
      'linkedName': linkedName,
    };
  }

  Rotation2d get heading => holonomicAngle;

  void move(num x, num y) {
    anchor = Translation2d(x, y);

    if (linkedName != null) {
      linked[linkedName!] = Pose2d(anchor, holonomicAngle);
    }
  }

  Waypoint clone() {
    return Waypoint(
      anchor: anchor,
      holonomicAngle: holonomicAngle,
      cruiseVelocity: cruiseVelocity,
      maxAcceleration: maxAcceleration,
      tolerance: tolerance,
      isLocked: isLocked,
      linkedName: linkedName,
    );
  }

  void setHeading(Rotation2d heading) {
    holonomicAngle = heading;
  }

  Translation2d headingHandlePosition() {
    return anchor + Translation2d.fromAngle(headingHandleLength, holonomicAngle);
  }

  bool isPointInAnchor(num xPos, num yPos, num radius) {
    return pow(xPos - anchor.x, 2) + pow(yPos - anchor.y, 2) < pow(radius, 2);
  }

  bool isPointInHeadingHandle(num xPos, num yPos, num radius) {
    Translation2d handle = headingHandlePosition();
    return pow(xPos - handle.x, 2) + pow(yPos - handle.y, 2) < pow(radius, 2);
  }

  bool startDragging(num xPos, num yPos, num anchorRadius, num headingRadius) {
    if (isPointInAnchor(xPos, yPos, anchorRadius)) {
      return _isAnchorDragging = true;
    } else if (isPointInHeadingHandle(xPos, yPos, headingRadius)) {
      return _isHeadingDragging = true;
    }
    return false;
  }

  void dragUpdate(num x, num y) {
    if (_isAnchorDragging && !isLocked) {
      move(x, y);
    } else if (_isHeadingDragging) {
      Rotation2d newHeading = Rotation2d.fromComponents(x - anchor.x, y - anchor.y);
      if (newHeading.radians.isFinite) {
        holonomicAngle = newHeading;
      }
    }
  }

  void stopDragging() {
    _isHeadingDragging = false;
    _isAnchorDragging = false;
  }

  @override
  bool operator ==(Object other) =>
      other is Waypoint &&
      other.runtimeType == runtimeType &&
      other.anchor == anchor &&
      other.holonomicAngle == holonomicAngle &&
      other.cruiseVelocity == cruiseVelocity &&
      other.maxAcceleration == maxAcceleration &&
      other.tolerance == tolerance &&
      other.linkedName == linkedName;

  @override
  int get hashCode => Object.hash(anchor, holonomicAngle, cruiseVelocity,
      maxAcceleration, tolerance, linkedName);
}
