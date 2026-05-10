# Context — Custom Profiled-PID PathPlanner Fork

## UI Vision (quick reference)
- **Path appearance:** Straight-line segments between waypoints (no Beziers). The *actual* driven path is shown by a translucent “ghost path” made from 20 ms physics samples.
- **Heading control:** Each waypoint shows a **heading handle** (small circle) connected to the waypoint. Dragging it rotates the **Swerve Heading** (holonomic angle) only.
- **Tolerance rings:** Each waypoint has a visible ring sized to its `tolerance` value.
- **Constraints panel:** For every waypoint, show numeric fields for:
  - X Position (M)
  - Y Position (M)
  - **Swerve Heading (Deg)**
  - **Cruise Velocity (M/S)**
  - **Max Accel (M/S²)**
  - **Target End Velocity (M/S)**
  - **Arrival Tolerance (M)**
- **Playback:** The preview scrubber uses precomputed physics states so time is physically accurate. The ghost path should reveal overshoot if tolerance is small and velocity high.
- **Export:** Path header includes a **Custom Export** button that calls the hook and passes all waypoint data.

## Progress Snapshot (May 10, 2026)
### ✅ Completed
- **Waypoint model refactor** (no Bezier controls):
  - Updated `lib/path/waypoint.dart` to include `holonomicAngle`, `cruiseVelocity`, `maxAcceleration`, `targetEndVelocity`, `tolerance`.
  - Added heading handle hit testing and drag logic.
- **Straight-line pathing:**
  - Updated `lib/path/pathplanner_path.dart` to sample straight segments and insert waypoints linearly.
- **Physics simulation:**
  - Added `lib/services/physics_sim_service.dart` with 20 ms stepping, tolerance-trigger transitions, and independent holonomic rotation.
- **Rendering updates:**
  - `lib/widgets/editor/path_painter.dart` now draws straight-line paths, heading handles, tolerance rings, and ghost path from physics samples.
  - Preview animation uses `PhysicsSimulationResult`.
- **Editor interaction updates:**
  - `lib/widgets/editor/split_path_editor.dart` uses physics sim results for preview and removes Bezier control logic.
  - Waypoint selection uses heading handles instead of control points.
- **Waypoint panel updates:**
  - `lib/widgets/editor/tree_widgets/waypoints_tree.dart` exposes the new physics constraint inputs.
- **Custom export hook:**
  - Added `lib/services/save_service.dart` with `exportToCustomFormat` placeholder.
  - Added button in `lib/widgets/editor/tree_widgets/path_tree.dart`.
- **Rendering dialog:**
  - `lib/widgets/trajectory_render.dart` and `lib/widgets/dialogs/trajectory_render_dialog.dart` support physics results.
- **Tests updated / added:**
  - Updated `test/path/waypoint_test.dart`, `test/path/pathplanner_path_test.dart`,
    `test/widgets/editor/tree_widgets/waypoints_tree_test.dart`,
    `test/util/path_optimizer_test.dart`, `test/trajectory/auto_simulator_test.dart`.
  - Added `test/services/physics_sim_service_test.dart`.

### ⚠️ Remaining / Needs Confirmation
- **Run tests:** Flutter isn’t available in the current environment, so tests haven’t executed.
  - Tests attempted: waypoint, pathplanner_path, waypoints_tree, path_optimizer,
    auto_simulator, physics_sim_service.
  - Result: `flutter` not found.

## Notes for Next Session
- If Flutter is available, run:
  - `flutter test test/path/waypoint_test.dart`
  - `flutter test test/path/pathplanner_path_test.dart`
  - `flutter test test/widgets/editor/tree_widgets/waypoints_tree_test.dart`
  - `flutter test test/util/path_optimizer_test.dart`
  - `flutter test test/trajectory/auto_simulator_test.dart`
  - `flutter test test/services/physics_sim_service_test.dart`
- If you want tighter physics fidelity (true trapezoid timing, separate angular constraints), extend `PhysicsSimService` with dedicated angular limits and phase timings.
