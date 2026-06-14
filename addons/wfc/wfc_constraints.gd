class_name WFCConstraints
extends RefCounted

var width: int = 0
var height: int = 0
var fixed_tiles: Array = []
var allowed_groups: Array = []
var blocked_groups: Array = []


func duplicate_deep() -> WFCConstraints:
	var copy = WFCConstraints.new()
	copy.width = width
	copy.height = height
	copy.fixed_tiles = fixed_tiles.duplicate(true)
	copy.allowed_groups = allowed_groups.duplicate(true)
	copy.blocked_groups = blocked_groups.duplicate(true)
	return copy
