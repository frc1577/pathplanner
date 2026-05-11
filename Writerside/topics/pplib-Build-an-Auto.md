# Build an Auto

<snippet id="build-an-auto">
## Configure Waypoints, Tolerances, and Constraints

In PathPlannerLib, the focus is on defining waypoints, tolerances, and constraints to guide the robot's autonomous behavior. These elements can be configured programmatically or through the GUI app.

### Waypoints
Waypoints define the key positions the robot should pass through during its autonomous routine. These can be specified as `Pose2d` objects, which include both position and orientation.

### Tolerances
Tolerances specify the acceptable deviation from the desired path or position. These can be defined in terms of distance (meters) and angle (radians).

### Constraints
Constraints impose limits on the robot's motion, such as maximum speed or acceleration. These ensure the robot operates within safe and efficient parameters.

> **Note**
>
> Always validate your waypoints, tolerances, and constraints to ensure they align with the robot's physical capabilities and the field layout.
>
{style="note"}

</snippet>
