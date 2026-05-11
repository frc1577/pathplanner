# Pathfinding

PathPlannerLib provides tools to define and utilize waypoints, tolerances, and constraints for autonomous navigation. These elements allow the robot to plan and execute paths effectively while avoiding obstacles.

## Waypoints
Waypoints are the key positions the robot should pass through. They can be defined as `Pose2d` objects, specifying both position and orientation.

## Tolerances
Tolerances define the acceptable deviation from the desired path or position. These ensure the robot stays within a safe and effective range of operation.

## Constraints
Constraints impose limits on the robot's motion, such as maximum speed or acceleration. These are critical for maintaining control and safety during autonomous operation.

> **Note**
>
> Always validate your waypoints, tolerances, and constraints to ensure they align with the robot's physical capabilities and the field layout.
>
{style="note"}
