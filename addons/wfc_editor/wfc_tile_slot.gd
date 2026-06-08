@tool
class_name WfcTileSlot
extends Control

## Set to true for the center tile (larger size, no checkbox).
@export var is_center: bool = false:
	set(v):
		is_center = v
		custom_minimum_size = _size_for(v)

signal checked(toggled: bool)

var _tex: TextureRect
var _label: Label
var _check: CheckBox
var _is_connected: bool = false


func _ready() -> void:
	custom_minimum_size = _size_for(is_center)

	_tex = TextureRect.new()
	_tex.name = "Tex"
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tex.modulate = Color(0.3, 0.3, 0.3, 1)
	add_child(_tex)

	_label = Label.new()
	_label.name = "Label"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 10 if not is_center else 12)
	_label.clip_text = true
	add_child(_label)

	if not is_center:
		_check = CheckBox.new()
		_check.name = "Check"
		_check.focus_mode = Control.FOCUS_NONE
		_check.hide()
		_check.toggled.connect(func(v): checked.emit(v))
		add_child(_check)

	_update_layout()


## Display [tile_name] with [texture]. Pass null texture to clear.
func set_tile(tile_name: String, texture: Texture2D) -> void:
	if texture:
		_tex.texture = texture; _label.text = tile_name
	else:
		_tex.texture = null; _label.text = ""


## Connected = full color; disconnected = grayscale.
func set_connected(connected: bool) -> void:
	_is_connected = connected
	_tex.modulate = Color.WHITE if connected else Color(0.35, 0.35, 0.35, 1)


## Show/hide the checkbox and set its state.
func set_check_visible(v: bool) -> void:
	if _check: _check.visible = v


func set_check_state(v: bool) -> void:
	if _check:
		_check.set_block_signals(true)
		_check.button_pressed = v
		_check.set_block_signals(false)


func _size_for(center: bool) -> Vector2:
	return Vector2(144, 144) if center else Vector2(72, 84)


func _update_layout() -> void:
	var sz = custom_minimum_size
	_tex.position = Vector2.ZERO
	_tex.size = sz - Vector2(0, 20)

	_label.position = Vector2(0, sz.y - 20)
	_label.size = Vector2(sz.x, 20)

	if _check:
		_check.position = Vector2(sz.x - 18, 2)
		_check.size = Vector2(16, 16)
