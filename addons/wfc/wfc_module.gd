@tool
class_name WFCModule
extends Resource

@export var module_name: String = ""

@export var weight: float = 1.0

@export var connectors: Dictionary = {
	"north": [],
	"east":  [],
	"south": [],
	"west":  [],
}

@export var preview_color: Color = Color.WHITE

@export var scene: PackedScene
