class_name GameMap

const TILE_WALL  = 0
const TILE_FLOOR = 1

const MIN_LEAF   = 10
const MAX_LEAF   = 20
const MIN_ROOM_W = 4
const MIN_ROOM_H = 3

var width: int
var height: int
var tiles: Array   # tiles[y][x] -> int
var rooms: Array   # Array of Rect2i


func _init(w: int, h: int) -> void:
	width = w
	height = h
	rooms = []
	tiles = []
	for _y in range(h):
		var row: Array = []
		for _x in range(w):
			row.append(TILE_WALL)
		tiles.append(row)


func get_tile(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= width or y >= height:
		return TILE_WALL  # treat out-of-bounds as wall
	return tiles[y][x]


func set_tile(x: int, y: int, value: int) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	tiles[y][x] = value


func is_walkable(x: int, y: int) -> bool:
	return get_tile(x, y) == TILE_FLOOR


# Returns a random floor tile position; call only after generate()
func get_random_floor(rng: RandomNumberGenerator) -> Vector2i:
	while true:
		var x := rng.randi_range(0, width - 1)
		var y := rng.randi_range(0, height - 1)
		if tiles[y][x] == TILE_FLOOR:
			return Vector2i(x, y)
	return Vector2i(1, 1)  # unreachable, satisfies type checker


func get_room_centers() -> Array:
	var centers: Array = []
	for r: Rect2i in rooms:
		centers.append(Vector2i(r.position.x + r.size.x / 2,
								r.position.y + r.size.y / 2))
	return centers


# ── BSP dungeon generation ────────────────────────────────────────────────────

func generate(rng: RandomNumberGenerator) -> void:
	rooms.clear()
	# Reset to all walls
	for y in range(height):
		for x in range(width):
			tiles[y][x] = TILE_WALL

	var root := Rect2i(1, 1, width - 2, height - 2)
	var leaves: Array = _bsp_split(root, rng)

	# Carve one room per leaf
	for leaf: Rect2i in leaves:
		var room := _random_room_in_leaf(leaf, rng)
		_carve_room(room)
		rooms.append(room)

	# Connect every adjacent pair of rooms via corridor
	for i in range(rooms.size() - 1):
		var ca := Vector2i(rooms[i].position.x + rooms[i].size.x / 2,
						   rooms[i].position.y + rooms[i].size.y / 2)
		var cb := Vector2i(rooms[i + 1].position.x + rooms[i + 1].size.x / 2,
						   rooms[i + 1].position.y + rooms[i + 1].size.y / 2)
		if rng.randi_range(0, 1) == 0:
			_carve_h_corridor(ca.x, cb.x, ca.y)
			_carve_v_corridor(ca.y, cb.y, cb.x)
		else:
			_carve_v_corridor(ca.y, cb.y, ca.x)
			_carve_h_corridor(ca.x, cb.x, cb.y)


func _bsp_split(region: Rect2i, rng: RandomNumberGenerator) -> Array:
	# Returns an array of leaf Rect2i that are small enough not to split further
	var result: Array = []
	var stack: Array = [region]

	while stack.size() > 0:
		var r: Rect2i = stack.pop_back()
		var can_split_h := r.size.x >= MIN_LEAF * 2
		var can_split_v := r.size.y >= MIN_LEAF * 2

		# If too large, force a split; if below max, randomly decide to stop
		var force_split := r.size.x > MAX_LEAF or r.size.y > MAX_LEAF
		if not force_split and (not can_split_h and not can_split_v):
			result.append(r)
			continue
		if not force_split and rng.randf() < 0.3:
			result.append(r)
			continue

		# Choose split direction
		var split_horizontally: bool
		if can_split_h and can_split_v:
			split_horizontally = rng.randi_range(0, 1) == 0
		elif can_split_h:
			split_horizontally = true
		elif can_split_v:
			split_horizontally = false
		else:
			result.append(r)
			continue

		if split_horizontally:
			var split_x := rng.randi_range(MIN_LEAF, r.size.x - MIN_LEAF)
			stack.append(Rect2i(r.position.x, r.position.y, split_x, r.size.y))
			stack.append(Rect2i(r.position.x + split_x, r.position.y,
								r.size.x - split_x, r.size.y))
		else:
			var split_y := rng.randi_range(MIN_LEAF, r.size.y - MIN_LEAF)
			stack.append(Rect2i(r.position.x, r.position.y, r.size.x, split_y))
			stack.append(Rect2i(r.position.x, r.position.y + split_y,
								r.size.x, r.size.y - split_y))

	return result


func _random_room_in_leaf(leaf: Rect2i, rng: RandomNumberGenerator) -> Rect2i:
	var max_w := max(MIN_ROOM_W, leaf.size.x - 2)
	var max_h := max(MIN_ROOM_H, leaf.size.y - 2)
	var rw := rng.randi_range(MIN_ROOM_W, max_w)
	var rh := rng.randi_range(MIN_ROOM_H, max_h)
	var rx := leaf.position.x + rng.randi_range(1, max(1, leaf.size.x - rw - 1))
	var ry := leaf.position.y + rng.randi_range(1, max(1, leaf.size.y - rh - 1))
	return Rect2i(rx, ry, rw, rh)


func _carve_room(room: Rect2i) -> void:
	for y in range(room.position.y, room.position.y + room.size.y):
		for x in range(room.position.x, room.position.x + room.size.x):
			set_tile(x, y, TILE_FLOOR)


func _carve_h_corridor(x1: int, x2: int, y: int) -> void:
	var x_start := min(x1, x2)
	var x_end   := max(x1, x2)
	for x in range(x_start, x_end + 1):
		set_tile(x, y, TILE_FLOOR)


func _carve_v_corridor(y1: int, y2: int, x: int) -> void:
	var y_start := min(y1, y2)
	var y_end   := max(y1, y2)
	for y in range(y_start, y_end + 1):
		set_tile(x, y, TILE_FLOOR)
