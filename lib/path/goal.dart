import 'package:pathplanner/path/waypoint.dart';

class Goal {
  List<Waypoint> waypoints;

  Goal({required this.waypoints});

  Goal.fromJson(Map<String, dynamic> json)
      : waypoints = [
          for (final waypointJson in json['waypoints'] ?? [])
            Waypoint.fromJson(waypointJson),
        ];

  Map<String, dynamic> toJson() {
    return {
      'waypoints': [
        for (final waypoint in waypoints) waypoint.toJson(),
      ],
    };
  }

  Goal clone() {
    return Goal(
      waypoints: [
        for (final waypoint in waypoints) waypoint.clone(),
      ],
    );
  }
}