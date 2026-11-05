import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/heading_strat.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  test('conditional heading uses robot x position', () {
    final strat = HeadingStrat(
      id: 'test',
      name: 'test',
      type: HeadingStratKinds.simpleOnCondition,
      degrees: 90,
      targetX: 0,
      targetY: 0,
      offsetDeg: 0,
      falseDegrees: 15,
      condition: 'robotPose > 5.5 && robotPose < 7',
    );

    expect(strat.resolveHeading(Translation2d(6, 0))?.degrees, closeTo(90, 1e-9));
    expect(strat.resolveHeading(Translation2d(5, 0))?.degrees, closeTo(15, 1e-9));
  });

  test('invalid conditional heading fails closed', () {
    final strat = HeadingStrat(
      id: 'test',
      name: 'test',
      type: HeadingStratKinds.simpleOnCondition,
      degrees: 90,
      targetX: 0,
      targetY: 0,
      offsetDeg: 0,
      falseDegrees: 15,
      condition: 'robotPose >',
    );

    expect(strat.resolveHeading(Translation2d(6, 0))?.degrees, closeTo(15, 1e-9));
  });

  test('conditional heading uses another heading when false', () {
    final strat = HeadingStrat(
      id: 'conditional',
      name: 'conditional',
      type: HeadingStratKinds.simpleOnCondition,
      degrees: 90,
      targetX: 0,
      targetY: 0,
      offsetDeg: 0,
      falseDegrees: 0,
      condition: 'false',
    );

    expect(
      strat.resolveHeading(Translation2d(0, 0))?.degrees,
      closeTo(0, 1e-9),
    );
  });
}