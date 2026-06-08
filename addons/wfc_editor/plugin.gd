@tool
extends EditorPlugin

var _panel: Control

func _enter_tree() -> void:
	_panel = WFCEditorPanel.new()
	EditorInterface.get_editor_main_screen().add_child(_panel)
	
	_panel.plugin = self
	_panel.hide()

func _exit_tree() -> void:
	if _panel:
		_panel.queue_free()

func _make_visible(visible: bool) -> void:
	if _panel == null:
		return
	_panel.visible = visible

func _get_plugin_name() -> String:
	return "WFCEditor"

func _has_main_screen() -> bool:
	return true
