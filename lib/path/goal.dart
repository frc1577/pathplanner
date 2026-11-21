import 'package:pathplanner/path/waypoint.dart';

class Goal {
  List<Waypoint> waypoints;
  String command;
  String name;

  bool finishWhenDriveFinishes;
  bool withSuccessCondition;
  bool withFailiureCondition;
  bool commandBasedGoal;

  String successCondition;
  String failiureCondition;
  String backUpGoal;

  Goal({
    required this.waypoints,
    this.command = '',
    this.name = '',
    this.finishWhenDriveFinishes = false,
    this.withSuccessCondition = false,
    this.withFailiureCondition = false,
    this.commandBasedGoal = false,
    this.successCondition = '',
    this.failiureCondition = '',
    this.backUpGoal = '',
  });

  Goal.fromJson(Map<String, dynamic> json)
      : command = json['command'] ?? '',
        name = json['name'] ?? '',
        finishWhenDriveFinishes = json['finishWhenDriveFinishes'] ?? false,
        withSuccessCondition = json['withSuccessCondition'] ?? false,
        withFailiureCondition = json['withFailiureCondition'] ?? false,
        commandBasedGoal = json['commandBasedGoal'] ?? false,
        successCondition = json['successCondition'] ?? json['endCond'] ?? '',
        failiureCondition = json['failiureCondition'] ?? '',
        backUpGoal = json['backUpGoal'] ?? '',
        waypoints = [
          for (final waypointJson in json['waypoints'] ?? [])
            Waypoint.fromJson(waypointJson),
        ];

  Map<String, dynamic> toJson() {
    return {
      'command': command,
      'name': name,
      'finishWhenDriveFinishes': finishWhenDriveFinishes,
      'withSuccessCondition': withSuccessCondition,
      'withFailiureCondition': withFailiureCondition,
      'commandBasedGoal': commandBasedGoal,
      'successCondition': successCondition,
      'failiureCondition': failiureCondition,
      'backUpGoal': backUpGoal,
      'waypoints': [
        for (final waypoint in waypoints) waypoint.toJson(),
      ],
    };
  }

  Goal clone() {
    return Goal(
      command: command,
      name: name,
      finishWhenDriveFinishes: finishWhenDriveFinishes,
      withSuccessCondition: withSuccessCondition,
      withFailiureCondition: withFailiureCondition,
      commandBasedGoal: commandBasedGoal,
      successCondition: successCondition,
      failiureCondition: failiureCondition,
      backUpGoal: backUpGoal,
      waypoints: [
        for (final waypoint in waypoints) waypoint.clone(),
      ],
    );
  }
}