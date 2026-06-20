import 'package:flutter_test/flutter_test.dart';
import 'package:pathplanner/services/save_service.dart';

void main() {
  test('parses ProfiledPIDSettings block with SyncedNumber values', () {
    final input = '''
@Sync("intakingController")
public static ProfiledPIDSettings intakingController = new ProfiledPIDSettings() {{
      x_kP = new SyncedNumber(3.5);
      x_kI = new SyncedNumber(0);
      x_kD = new SyncedNumber(0);

      y_kP = new SyncedNumber(3.5);
      y_kI = new SyncedNumber(0);
      y_kD = new SyncedNumber(0);

      rotation_kP = new SyncedNumber(5);
      rotation_kI = new SyncedNumber(0);
      rotation_kD = new SyncedNumber(0);

      x_motionCruiseVelocity = new SyncedNumber(2.5);
      x_motionAcceleration = new SyncedNumber(5);

      y_motionCruiseVelocity = new SyncedNumber(2.5);
      y_motionAcceleration = new SyncedNumber(5);

      rotation_motionAcceleration = new SyncedNumber(5);
      rotation_motionCruiseVelocity = new SyncedNumber(12);
    }};
''';

    final parsed = SaveService.importFromJavaControllers(input);
    expect(parsed.length, 1);

    final s = parsed.first;
    expect(s.name, 'intakingController');
    expect(s.kp, 3.5);
    expect(s.ki, 0.0);
    expect(s.kd, 0.0);
    expect(s.cruiseVelocity, 2.5);
    expect(s.maxAcceleration, 5.0);
    expect(s.angularKp, 5.0);
    expect(s.angularMaxVelocity, 12.0);
  });

  test('parses plain numeric assignments too', () {
    final input = '''
public static ProfiledPIDSettings foo = new ProfiledPIDSettings() {{
  x_kP = 1.25;
  x_kI = 0.5;
  rotation_kP = 4;
}};
''';

    final parsed = SaveService.importFromJavaControllers(input);
    expect(parsed.length, 1);

    final s = parsed.first;
    expect(s.name, 'foo');
    expect(s.kp, 1.25);
    expect(s.ki, 0.5);
    expect(s.angularKp, 4.0);
  });
}
