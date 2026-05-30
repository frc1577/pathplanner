import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

const num epsilon = 0.01;

void main() {
  group('Basic functions', () {
    test('Constructor functions', () {
      Waypoint w = Waypoint(
        anchor: const Translation2d(2.0, 2.0),
        holonomicAngle: Rotation2d.fromDegrees(45),
        kp: 2.5,
        ki: 0.0,
        kd: 3.5,
        tolerance: 0.15,
      );

      expect(w.anchor, const Translation2d(2.0, 2.0));
      expect(w.holonomicAngle.degrees, closeTo(45.0, epsilon));
      expect(w.kp, 2.5);
      expect(w.kd, 3.5);
      expect(w.tolerance, 0.15);
    });

    test('toJson/fromJson interoperability', () {
      Waypoint w = Waypoint(
        anchor: const Translation2d(2.0, 2.0),
        holonomicAngle: Rotation2d.fromDegrees(30),
        kp: 2.0,
        ki: 0.0,
        kd: 4.0,
        tolerance: 0.2,
      );

      Map<String, dynamic> json = w.toJson();
      Waypoint fromJson = Waypoint.fromJson(json);

      expect(fromJson, w);
    });

    test('Proper cloning', () {
      Waypoint w = Waypoint(
        anchor: const Translation2d(2.0, 2.0),
        holonomicAngle: Rotation2d.fromDegrees(30),
        kp: 2.0,
        ki: 0.0,
        kd: 4.0,
        tolerance: 0.2,
      );
      Waypoint cloned = w.clone();

      expect(cloned, w);

      cloned.anchor = Translation2d(cloned.anchor.x + 1.0, cloned.anchor.y);

      expect(w, isNot(cloned));
    });

    test('equals/hashCode', () {
      Waypoint w1 = Waypoint(
        anchor: const Translation2d(2.0, 2.0),
        holonomicAngle: Rotation2d.fromDegrees(30),
        kp: 2.0,
        ki: 0.0,
        kd: 4.0,
        tolerance: 0.2,
      );
      Waypoint w2 = Waypoint(
        anchor: const Translation2d(2.0, 2.0),
        holonomicAngle: Rotation2d.fromDegrees(30),
        kp: 2.0,
        ki: 0.0,
        kd: 4.0,
        tolerance: 0.2,
      );
      Waypoint w3 = Waypoint(
        anchor: const Translation2d(2.0, 2.0),
        holonomicAngle: Rotation2d.fromDegrees(31),
        kp: 2.0,
        ki: 0.0,
        kd: 4.0,
        tolerance: 0.2,
      );

      expect(w2, w1);
      expect(w3, isNot(w1));

      expect(w2.hashCode, w1.hashCode);
      expect(w3.hashCode, isNot(w1.hashCode));
    });
  });

  group('Heading', () {
    test('Heading returns holonomic angle', () {
      Waypoint w = Waypoint(
        anchor: const Translation2d(2.0, 2.0),
        holonomicAngle: Rotation2d.fromDegrees(90),
      );

      expect(w.heading.degrees, closeTo(90, epsilon));
    });
  });

  test('move', () {
    Waypoint w = Waypoint(
      anchor: const Translation2d(2.0, 2.0),
      holonomicAngle: Rotation2d.fromDegrees(45),
    );

    w.move(5.5, 4.5);

    expect(w.anchor, const Translation2d(5.5, 4.5));
    expect(w.holonomicAngle.degrees, closeTo(45, epsilon));
  });

  test('set heading', () {
    Waypoint w = Waypoint(
      anchor: const Translation2d(2.0, 2.0),
      holonomicAngle: Rotation2d.fromDegrees(10),
    );

    w.setHeading(Rotation2d.fromDegrees(107.5));

    expect(w.holonomicAngle.degrees, closeTo(107.5, epsilon));
  });
}
