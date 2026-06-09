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
		$Tex.texture = texture
		_ts_log("set_tile name=%s tex=%dx%d" % [tile_name, texture.get_width(), texture.get_height()])
	else:
		$Tex.texture = null
		_ts_log("set_tile name=%s tex=NULL" % tile_name)

	if is_center:
		$Tex.modulate = Color.WHITE


func set_connected(connected: bool) -> void:
	_is_connected = connected
	$Tex.modulate = Color.WHITE if connected else Color(0.35, 0.35, 0.35, 1)


func _ts_log(msg: String) -> void:
	var f = FileAccess.open("user://wfc_editor.log", FileAccess.WRITE_READ)
	if f:
		f.seek_end()
		f.store_line(msg)
		f.close()


func set_check_visible(v: bool) -> void:
	if not is_center:
		$Check.visible = v


func set_check_state(v: bool) -> void:
	if not is_center:
		$Check.set_block_signals(true)
		$Check.button_pressed = v
		$Check.set_block_signals(false)
