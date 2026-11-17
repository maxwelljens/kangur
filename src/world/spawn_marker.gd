class_name SpawnMarker
extends Marker2D
## A spawn position for one team. Four lines of script keep spawns
## queryable (`World.spawn_points(team)`) without name string parsing.

@export var team: int = Enums.Team.BASTION