import 'package:pathplanner/path/waypoint.dart';
import 'package:pathplanner/services/log.dart';

class SaveService {
  static void exportToCustomFormat(List<Waypoint> waypoints) {
    // TODO: Implement custom export writer for your autonomous framework.
    Log.info(
        'Custom export hook invoked with ${waypoints.length} waypoints.');
  }
}
