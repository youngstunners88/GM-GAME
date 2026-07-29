class_name SpaceShipHull
extends Resource
## Stat pack for a v1.3 ship chassis.
##
## A Resource, not a Node: hulls are DATA. That keeps the hangar/selection
## screen from instancing scene trees just to show a stat comparison, and lets
## hulls be authored as .tres later without a code change.

@export var display_name: String = "Hull"
@export var max_hull: int = 100
@export var thrust: float = 600.0
@export var rotation_speed: float = 3.4
@export var max_speed: float = 700.0
@export var tint: Color = Color.WHITE
