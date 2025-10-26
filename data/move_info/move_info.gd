extends RefCounted
class_name MoveInfo

var from_tile: Vector2i
var to_tile: Vector2i
var gem: Gem
var from_global_position: Vector2
var to_global_position: Vector2

func _init(from: Vector2i, to: Vector2i, gem_ref: Gem, from_global: Vector2 = Vector2.ZERO, to_global: Vector2 = Vector2.ZERO):
	from_tile = from
	to_tile = to
	gem = gem_ref
	from_global_position = from_global
	to_global_position = to_global
