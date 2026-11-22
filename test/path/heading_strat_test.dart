import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/path/heading_strat.dart';
import 'package:pathplanner/util/wpimath/geometry.dart';

void main() {
  group('HeadingStratKinds', () {
    test('exposes only supported kinds without onCondition variants', () {
      expect(
        HeadingStratKinds.values,
        equals([
          HeadingStratKinds.simple,
          HeadingStratKinds.faceTarget,
          HeadingStratKinds.named,
        ]),
      );
      expect(
        HeadingStratKinds.labelFor(HeadingStratKinds.simple),
        'Simple Heading Strat',
      );
      expect(
        HeadingStratKinds.labelFor(HeadingStratKinds.faceTarget),
        'Face Target Heading Strat',
      );
      expect(
        HeadingStratKinds.labelFor(HeadingStratKinds.named),
        'Named Heading Strat',
      );
    });
  });

  group('HeadingStrat.resolveHeading', () {
    test('simple heading strat resolves to configured degrees', () {
      final strat = HeadingStrat(
        name: 'simple',
        type: HeadingStratKinds.simple,
        degrees: 90,
        targetX: 0,
        targetY: 0,
        offsetDeg: 0,
      );

      expect(
        strat.resolveHeading(const Translation2d(2, 3))?.degrees,
        closeTo(90, 1e-9),
      );
    });

    test('face target heading strat resolves angle to target plus offset', () {
      final strat = HeadingStrat(
        name: 'faceTarget',
        type: HeadingStratKinds.faceTarget,
        degrees: 0,
        targetX: 4,
        targetY: 0,
        offsetDeg: 30,
      );

      expect(
        strat.resolveHeading(const Translation2d(0, 0))?.degrees,
        closeTo(30, 1e-9),
      );
    });

    test('named heading strat respects simple and faceTarget innerType', () {
      final simpleNamed = HeadingStrat(
        name: 'namedSimple',
        type: HeadingStratKinds.named,
        degrees: -45,
        targetX: 5,
        targetY: 5,
        offsetDeg: 90,
        innerType: HeadingStratKinds.simple,
      );

      expect(
        simpleNamed.resolveHeading(const Translation2d(0, 0))?.degrees,
        closeTo(-45, 1e-9),
      );

      final faceTargetNamed = HeadingStrat(
        name: 'namedTarget',
        type: HeadingStratKinds.named,
        degrees: -45,
        targetX: 0,
        targetY: 5,
        offsetDeg: 0,
        innerType: HeadingStratKinds.faceTarget,
      );

      expect(
        faceTargetNamed.resolveHeading(const Translation2d(0, 0))?.degrees,
        closeTo(90, 1e-9),
      );
    });
  });

  group('HeadingStrat serialization and cloning', () {
    test('fromJson falls back to simple for unknown or removed types', () {
      final strat = HeadingStrat.fromJson({
        'name': 'legacy',
        'type': 'SimpleHeadingStratOnCondition',
        'degrees': 135,
      });

      expect(strat.type, HeadingStratKinds.simple);
      expect(strat.degrees, closeTo(135, 1e-9));
      expect(strat.toJson(), {
        'name': 'legacy',
        'type': HeadingStratKinds.simple,
        'degrees': 135.0,
      });
    });

    test('toJson serializes faceTarget and named strats with inner parameters', () {
      final faceTarget = HeadingStrat(
        name: 'aim',
        type: HeadingStratKinds.faceTarget,
        degrees: 0,
        targetX: 2.5,
        targetY: 4.0,
        offsetDeg: -15.0,
      );

      expect(faceTarget.toJson(), {
        'name': 'aim',
        'type': HeadingStratKinds.faceTarget,
        'offsetDeg': -15.0,
        'targetX': 2.5,
        'targetY': 4.0,
      });

      final namedSimple = HeadingStrat(
        name: 'namedSimpleStrat',
        type: HeadingStratKinds.named,
        degrees: 45.0,
        targetX: 1,
        targetY: 1,
        offsetDeg: 10,
        innerType: HeadingStratKinds.simple,
      );

      expect(namedSimple.toJson(), {
        'name': 'namedSimpleStrat',
        'type': HeadingStratKinds.named,
        'innerType': HeadingStratKinds.simple,
        'degrees': 45.0,
      });

      final namedFaceTarget = HeadingStrat(
        name: 'namedStrat',
        type: HeadingStratKinds.named,
        degrees: 45,
        targetX: 1.5,
        targetY: 2.5,
        offsetDeg: 10.0,
        innerType: HeadingStratKinds.faceTarget,
      );

      expect(namedFaceTarget.toJson(), {
        'name': 'namedStrat',
        'type': HeadingStratKinds.named,
        'innerType': HeadingStratKinds.faceTarget,
        'offsetDeg': 10.0,
        'targetX': 1.5,
        'targetY': 2.5,
      });
    });

    test('clone creates an independent copy', () {
      final original = HeadingStrat(
        name: 'orig',
        type: HeadingStratKinds.simple,
        degrees: 60,
        targetX: 1,
        targetY: 2,
        offsetDeg: 5,
        innerType: HeadingStratKinds.simple,
      );

      final copy = original.clone()
        ..name = 'mutated'
        ..degrees = 180;

      expect(original.name, 'orig');
      expect(original.degrees, closeTo(60, 1e-9));
      expect(copy.name, 'mutated');
      expect(copy.degrees, closeTo(180, 1e-9));
    });
  });
}