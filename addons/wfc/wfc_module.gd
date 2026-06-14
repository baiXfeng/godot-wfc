@tool
class_name WFCModule
extends Resource

@export var module_name: String = ""

@export var weight: float = 1.0

@export var groups: PackedStringArray = PackedStringArray()

@export var connectors: Dictionary = {
	"north": [],
	"east":  [],
	"south": [],
	"west":  [],
}

@export var preview_color: Color = Color.WHITE

@export var scene: PackedScene

# Non-exported — set by WFCConfigLoader when importing from connectId-based data.
# Maps direction ("north"/"east"/"south"/"west") to Array[int]. Empty means unused.
var connect_id_l: Dictionary = {}
var connect_id_r: Dictionary = {}
