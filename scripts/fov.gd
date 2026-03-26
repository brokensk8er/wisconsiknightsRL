class_name FOV

# visible: tiles the player can currently see (cleared each compute())
# explored: tiles the player has ever seen (persists — fog of war memory)
var visible: Dictionary   # Vector2i -> true
var explored: Dictionary  # Vector2i -> true

# Octant transform table: [xx, xy, yx, yy]
const OCTANTS: Array = [
	[ 1,  0,  0,  1],
	[ 0,  1,  1,  0],
	[ 0, -1,  1,  0],
	[-1,  0,  0,  1],
	[-1,  0,  0, -1],
	[ 0, -1, -1,  0],
	[ 0,  1, -1,  0],
	[ 1,  0,  0, -1],
]


func _init() -> void:
	visible = {}
	explored = {}


func compute(origin_x: int, origin_y: int, radius: int, map: GameMap) -> void:
	visible.clear()
	# Origin is always visible
	var origin := Vector2i(origin_x, origin_y)
	visible[origin] = true
	explored[origin] = true

	for oct in OCTANTS:
		_cast_light(origin_x, origin_y, radius, 1, 1.0, 0.0,
					oct[0], oct[1], oct[2], oct[3], map)


func is_visible(x: int, y: int) -> bool:
	return visible.get(Vector2i(x, y), false)


func is_explored(x: int, y: int) -> bool:
	return explored.get(Vector2i(x, y), false)


# Recursive shadowcasting — Björn Bergström's algorithm
func _cast_light(cx: int, cy: int, radius: int, row: int,
				 start_slope: float, end_slope: float,
				 xx: int, xy: int, yx: int, yy: int,
				 map: GameMap) -> void:
	if start_slope < end_slope:
		return

	var radius_sq := radius * radius
	var new_start := 0.0
	var blocked := false

	var j := row
	while j <= radius and not blocked:
		blocked = false
		var dx := -j - 1
		var dy := -j

		while dx <= 0:
			dx += 1
			var map_x := cx + dx * xx + dy * xy
			var map_y := cy + dx * yx + dy * yy

			var l_slope := (dx - 0.5) / (dy + 0.5)
			var r_slope := (dx + 0.5) / (dy - 0.5)

			if start_slope < r_slope:
				continue
			if end_slope > l_slope:
				break

			if dx * dx + dy * dy <= radius_sq:
				var cell := Vector2i(map_x, map_y)
				visible[cell] = true
				explored[cell] = true

			if blocked:
				if map.get_tile(map_x, map_y) == GameMap.TILE_WALL:
					new_start = r_slope
					continue
				else:
					blocked = false
					start_slope = new_start
			else:
				if map.get_tile(map_x, map_y) == GameMap.TILE_WALL and j < radius:
					blocked = true
					_cast_light(cx, cy, radius, j + 1, start_slope, l_slope,
								xx, xy, yx, yy, map)
					new_start = r_slope
		j += 1

	# If we ended the row still blocked, the shadow extends to the next row
	# (handled by the recursive call above; nothing more needed here)
