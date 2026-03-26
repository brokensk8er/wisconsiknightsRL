class_name Entity

var map_x: int
var map_y: int
var glyph: String
var color: String
var entity_name: String


func _init(x: int, y: int, p_glyph: String, p_color: String, p_name: String) -> void:
	map_x = x
	map_y = y
	glyph = p_glyph
	color = p_color
	entity_name = p_name


func move(dx: int, dy: int) -> void:
	map_x += dx
	map_y += dy
