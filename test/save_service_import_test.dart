import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/services/save_service.dart';

void main() {
  test('import Java-style waypoints', () {
    final input = '''
        add(new Waypoint(new Pose2d(3.15, 7.58, new Rotation2d(Math.toRadians(0))), 1, 360, AutoConstants.mediumPID));
        add(new Waypoint(new Pose2d(5.569155555555556, 7.58, new Rotation2d(Math.toRadians(0))), 1, 360, AutoConstants.mediumPID));
        add(new Waypoint(new Pose2d(6.2746, 7.400977777777777, new Rotation2d(Math.toRadians(270))), 1, 360, AutoConstants.mediumPID));
        add(new Waypoint(new Pose2d(5.891644444444445, 3.8185568181818184, new Rotation2d(Math.toRadians(270))), 2.5, 360, AutoConstants.mediumPID));
        add(new Waypoint(new Pose2d(5.891644444444445, 2.860022727272727, new Rotation2d(Math.toRadians(290))), 2.5, 360, AutoConstants.mediumPID));
        add(new Waypoint(new Pose2d(9.280068181818182, 4.601875, new Rotation2d(Math.toRadians(29.999999999999996))), 2, 360, AutoConstants.mediumPID));
        add(new Waypoint(new Pose2d(8.239079545454544, 6.776613636363636, new Rotation2d(Math.toRadians(180))), 2, 360, AutoConstants.mediumPID));
        add(new Waypoint(new Pose2d(6.528, 5.707911111111112, new Rotation2d(Math.toRadians(160))), 1.5, 360, AutoConstants.fastPID));
        add(new Waypoint(new Pose2d(5.722611806797853, 5.50339892665474, new Rotation2d(Math.toRadians(135))), 1, 360, AutoConstants.fastPID));
    ''';

    final waypoints = SaveService.importFromJavaWaypoints(input);

    expect(waypoints.length, 9);

    expect((waypoints[0].anchor.x - 3.15).abs() < 1e-6, true);
    expect((waypoints[0].anchor.y - 7.58).abs() < 1e-6, true);
    expect((waypoints[2].holonomicAngle.degrees - 270).abs() < 1e-6, true);
    expect((waypoints[8].anchor.x - 5.722611806797853).abs() < 1e-9, true);
  });
}
