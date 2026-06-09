@tool
class_name WfcTileItem
extends PanelContainer

signal pressed


func _ready() -> void:
	gui_input.connect(_on_gui_input)


func setup(tile_name: String, tex: Texture2D) -> void:
	$VBox/Tex.texture = tex
	$VBox/Label.text = tile_name


func set_highlight(on: bool) -> void:
	var s = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	s.border_color = Color(0.3, 0.7, 1.0, 1) if on else Color(0.15, 0.15, 0.15, 1)
	add_theme_stylebox_override("panel", s)


func set_count(count: int) -> void:
	if count > 0:
		$VBox/Label.text = str(count)
		modulate = Color.WHITE
	else:
		$VBox/Label.text = ""
		modulate = Color(0.5, 0.5, 0.5, 1)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
