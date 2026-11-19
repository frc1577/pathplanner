import 'package:pathplanner/path/waypoint.dart';

class Goal {
  List<Waypoint> waypoints;
  String command;
  String name;
  String endCond;

  Goal({
    required this.waypoints,
    this.command = '',
    this.endCond = '',
    this.name = '',
  });

  Goal.fromJson(Map<String, dynamic> json)
      : command = json['command'] ?? '',
        endCond = json['endCond'] ?? '',
        name = json['name'] ?? '',
        waypoints = [
          for (final waypointJson in json['waypoints'] ?? [])
            Waypoint.fromJson(waypointJson),
        ];

  Map<String, dynamic> toJson() {
    return {
      'command': command,
      'endCond': endCond,
      'name': name,
      'waypoints': [
        for (final waypoint in waypoints) waypoint.toJson(),
      ],
    };
  }

  Goal clone() {
    return Goal(
      command: command,
      endCond: endCond,
      name: name,
      waypoints: [
        for (final waypoint in waypoints) waypoint.clone(),
      ],
    );
  }
}