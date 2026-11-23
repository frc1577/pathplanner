import 'package:collection/collection.dart';
import 'package:pathplanner/path/waypoint.dart';

class Goal {
  String name;
  List<Waypoint> waypoints;
  String command;
  bool finishWhenDriveFinishes;
  bool withSuccessCondition;
  String successCondition;
  bool withFailiureCondition;
  String failiureCondition;
  String backUpGoal;
  bool commandBasedGoal;

  Goal({
    this.name = '',
    required this.waypoints,
    this.command = '',
    this.finishWhenDriveFinishes = true,
    this.withSuccessCondition = false,
    this.successCondition = '',
    this.withFailiureCondition = false,
    this.failiureCondition = '',
    this.backUpGoal = '',
    this.commandBasedGoal = false,
  });

  factory Goal.fromJson(Map<String, dynamic> json) {
    final legacyHeadingStrat = json['headingStratName'] as String?;
    final legacyControllerSetting = json['controllerSettingName'] as String?;

    final waypoints = (json['waypoints'] as List<dynamic>? ?? [])
        .map((w) {
          final wp = Waypoint.fromJson(w as Map<String, dynamic>);
          wp.headingStratName ??= legacyHeadingStrat;
          wp.controllerSettingName ??= legacyControllerSetting;
          return wp;
        })
        .toList();

    return Goal(
      name: (json['name'] as String?) ?? '',
      waypoints: waypoints,
      command: (json['command'] as String?) ?? '',
      finishWhenDriveFinishes:
          (json['finishWhenDriveFinishes'] as bool?) ?? true,
      withSuccessCondition: (json['withSuccessCondition'] as bool?) ?? false,
      successCondition: (json['successCondition'] as String?) ?? '',
      withFailiureCondition: (json['withFailiureCondition'] as bool?) ?? false,
      failiureCondition: (json['failiureCondition'] as String?) ?? '',
      backUpGoal: (json['backUpGoal'] as String?) ?? '',
      commandBasedGoal: (json['commandBasedGoal'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'waypoints': [for (final wp in waypoints) wp.toJson()],
      'command': command,
      'finishWhenDriveFinishes': finishWhenDriveFinishes,
      'withSuccessCondition': withSuccessCondition,
      'successCondition': successCondition,
      'withFailiureCondition': withFailiureCondition,
      'failiureCondition': failiureCondition,
      'backUpGoal': backUpGoal,
      'commandBasedGoal': commandBasedGoal,
    };
  }

  Goal clone() {
    return Goal(
      name: name,
      waypoints: [for (final wp in waypoints) wp.clone()],
      command: command,
      finishWhenDriveFinishes: finishWhenDriveFinishes,
      withSuccessCondition: withSuccessCondition,
      successCondition: successCondition,
      withFailiureCondition: withFailiureCondition,
      failiureCondition: failiureCondition,
      backUpGoal: backUpGoal,
      commandBasedGoal: commandBasedGoal,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Goal &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          const ListEquality().equals(waypoints, other.waypoints) &&
          command == other.command &&
          finishWhenDriveFinishes == other.finishWhenDriveFinishes &&
          withSuccessCondition == other.withSuccessCondition &&
          successCondition == other.successCondition &&
          withFailiureCondition == other.withFailiureCondition &&
          failiureCondition == other.failiureCondition &&
          backUpGoal == other.backUpGoal &&
          commandBasedGoal == other.commandBasedGoal;

  @override
  int get hashCode => Object.hash(
        name,
        const ListEquality().hash(waypoints),
        command,
        finishWhenDriveFinishes,
        withSuccessCondition,
        successCondition,
        withFailiureCondition,
        failiureCondition,
        backUpGoal,
        commandBasedGoal,
      );
}