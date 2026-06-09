@tool
class_name WfcTileSlot
extends Control

## Set to true for center tiles to hide the checkbox permanently.
@export var is_center: bool = false:
	set(v):
		is_center = v
		if is_inside_tree() and $Check:
			$Check.visible = false

signal checked(toggled: bool)

var _is_connected: bool = false


func _ready() -> void:
	if $Check:
		$Check.toggled.connect(func(v): checked.emit(v))
		if is_center:
			$Check.visible = false


func set_tile(tile_name: String, texture: Texture2D) -> void:
	if texture:
		$Tex.texture = texture; $Label.text = tile_name
	else:
		$Tex.texture = null; $Label.text = ""


func set_connected(connected: bool) -> void:
	_is_connected = connected
	$Tex.modulate = Color.WHITE if connected else Color(0.35, 0.35, 0.35, 1)


func set_check_visible(v: bool) -> void:
	if not is_center:
		$Check.visible = v


func set_check_state(v: bool) -> void:
	if not is_center:
		$Check.set_block_signals(true)
		$Check.button_pressed = v
		$Check.set_block_signals(false)
