extends Node

const MAP_W       := 80
const MAP_H       := 50
const FOV_RADIUS  := 8
const NUM_ENEMIES := 8
const NUM_POTIONS := 6
const NUM_SCROLLS := 4

var map: GameMap
var fov: FOV
var player: Player
var enemies: Array  # Array of Enemy
var items: Array    # Array of Item
var renderer: Renderer
var rng: RandomNumberGenerator
var log_message: String = ""

# item_id_system: effect (String) -> {appearance, color, kind, identified}
var item_id_system: Dictionary = {}

@onready var display: RichTextLabel = $Display


func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	_new_game()


func _new_game() -> void:
	log_message = "Welcome to the Badger Depths!"
	_build_id_system()

	# Build map
	map = GameMap.new(MAP_W, MAP_H)
	map.generate(rng)

	# Place player at center of first room
	var centers := map.get_room_centers()
	var start: Vector2i = centers[0] if centers.size() > 0 else Vector2i(5, 5)
	player = Player.new(start.x, start.y)

	# Place enemies — avoid the first room
	enemies = []
	var first_room: Rect2i = map.rooms[0] if map.rooms.size() > 0 else Rect2i(0, 0, 0, 0)
	var enemy_types := ["cheese_golem", "ice_troll", "bar_brawler"]
	var placed := 0
	var attempts := 0
	while placed < NUM_ENEMIES and attempts < 1000:
		attempts += 1
		var pos := map.get_random_floor(rng)
		if first_room.has_point(pos):
			continue
		if _entity_at(pos.x, pos.y) != null:
			continue
		var etype := enemy_types[rng.randi_range(0, enemy_types.size() - 1)]
		enemies.append(Enemy.new(pos.x, pos.y, etype))
		placed += 1

	# Place items
	items = []
	_place_items()

	# FOV
	fov = FOV.new()
	fov.compute(player.map_x, player.map_y, FOV_RADIUS, map)

	# Renderer
	renderer = Renderer.new()
	_redraw()


# ── Item identification system ────────────────────────────────────────────────

func _build_id_system() -> void:
	var potion_effects := ["heal", "poison", "full_heal", "map_reveal", "speed", "confusion"]
	var potion_appearances := [
		{appearance = "foamy potion",  color = "#DDDDFF"},
		{appearance = "golden potion", color = "#FFD700"},
		{appearance = "red potion",    color = "#FF4444"},
		{appearance = "blue potion",   color = "#4444FF"},
		{appearance = "green potion",  color = "#44FF44"},
		{appearance = "murky potion",  color = "#886644"},
	]
	var scroll_effects := ["identify", "teleport", "light", "fire"]
	var scroll_appearances := [
		{appearance = "ZELK scroll", color = "#FFFFF0"},
		{appearance = "FRIM scroll", color = "#FFFFF0"},
		{appearance = "BORK scroll", color = "#FFFFF0"},
		{appearance = "VASH scroll", color = "#FFFFF0"},
	]

	_shuffle_array(potion_appearances)
	_shuffle_array(scroll_appearances)

	item_id_system = {}
	for i in potion_effects.size():
		item_id_system[potion_effects[i]] = {
			appearance = potion_appearances[i].appearance,
			color      = potion_appearances[i].color,
			kind       = "potion",
			identified = false,
		}
	for i in scroll_effects.size():
		item_id_system[scroll_effects[i]] = {
			appearance = scroll_appearances[i].appearance,
			color      = scroll_appearances[i].color,
			kind       = "scroll",
			identified = false,
		}


func _shuffle_array(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _place_items() -> void:
	var potion_effects := item_id_system.keys().filter(
		func(k): return item_id_system[k].kind == "potion")
	var scroll_effects := item_id_system.keys().filter(
		func(k): return item_id_system[k].kind == "scroll")

	var to_place: Array = []
	for _i in range(NUM_POTIONS):
		to_place.append(potion_effects[rng.randi_range(0, potion_effects.size() - 1)])
	for _i in range(NUM_SCROLLS):
		to_place.append(scroll_effects[rng.randi_range(0, scroll_effects.size() - 1)])

	for effect in to_place:
		var attempts := 0
		while attempts < 500:
			attempts += 1
			var pos := map.get_random_floor(rng)
			if _entity_at(pos.x, pos.y) != null:
				continue
			if _item_at(pos.x, pos.y) != null:
				continue
			var data: Dictionary = item_id_system[effect]
			items.append(Item.new(pos.x, pos.y, effect,
								  data.appearance, data.color, data.kind))
			break


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return

	var dx := 0
	var dy := 0
	match event.keycode:
		KEY_UP,    KEY_K, KEY_W: dy = -1
		KEY_DOWN,  KEY_J, KEY_S: dy =  1
		KEY_LEFT,  KEY_H, KEY_A: dx = -1
		KEY_RIGHT, KEY_L, KEY_D: dx =  1
		KEY_Y: dx = -1; dy = -1
		KEY_U: dx =  1; dy = -1
		KEY_B: dx = -1; dy =  1
		KEY_N: dx =  1; dy =  1
		KEY_G: _pickup_item(); return
		_: return

	if dx != 0 or dy != 0:
		_player_turn(dx, dy)


# ── Turn logic ────────────────────────────────────────────────────────────────

func _player_turn(dx: int, dy: int) -> void:
	var tx := player.map_x + dx
	var ty := player.map_y + dy

	# Bump into enemy — no-op at MVP (no combat yet)
	if _entity_at(tx, ty) != null:
		log_message = "You bump into the %s." % (_entity_at(tx, ty) as Enemy).entity_name
		_redraw()
		return

	# Wall check
	if not map.is_walkable(tx, ty):
		return

	player.move(dx, dy)

	# Check for item underfoot
	var underfoot := _item_at(player.map_x, player.map_y)
	if underfoot != null:
		log_message = "You see a %s." % underfoot.display_name(player)
	else:
		log_message = ""

	fov.compute(player.map_x, player.map_y, FOV_RADIUS, map)
	_enemy_turn()
	_redraw()


func _enemy_turn() -> void:
	var state := {player = player, map = map, fov = fov}
	for enemy: Enemy in enemies:
		enemy.act(state)


func _pickup_item() -> void:
	var item := _item_at(player.map_x, player.map_y)
	if item == null:
		log_message = "There is nothing here to pick up."
		_redraw()
		return

	items.erase(item)
	var result := item.use(player)
	log_message = result.message

	# Handle side-effect of the effect
	match result.effect:
		"map_reveal":
			_reveal_map()
		"teleport":
			_teleport_player()
		"light":
			fov.compute(player.map_x, player.map_y, FOV_RADIUS + 4, map)
		"identify":
			_identify_random_item()

	# Mark the appearance as identified in our lookup table
	if item_id_system.has(result.effect):
		item_id_system[result.effect].identified = true

	_redraw()


func _reveal_map() -> void:
	for y in range(MAP_H):
		for x in range(MAP_W):
			if map.get_tile(x, y) == GameMap.TILE_FLOOR:
				fov.explored[Vector2i(x, y)] = true


func _teleport_player() -> void:
	var pos := map.get_random_floor(rng)
	player.map_x = pos.x
	player.map_y = pos.y
	fov.compute(player.map_x, player.map_y, FOV_RADIUS, map)


func _identify_random_item() -> void:
	# Identify a random unidentified item type the player has seen
	var unknown := item_id_system.keys().filter(
		func(k): return not item_id_system[k].identified)
	if unknown.size() == 0:
		return
	var effect: String = unknown[rng.randi_range(0, unknown.size() - 1)]
	item_id_system[effect].identified = true
	player.identify(effect)
	log_message += "  You now know: %s" % Item.TRUE_NAMES.get(effect, effect)


# ── Rendering ─────────────────────────────────────────────────────────────────

func _redraw() -> void:
	renderer.update_camera(player.map_x, player.map_y, MAP_W, MAP_H)
	var bbcode := renderer.render(map, fov, player, enemies, items, log_message)
	display.text = bbcode


# ── Helpers ───────────────────────────────────────────────────────────────────

# Returns the Enemy at (x, y), or null
func _entity_at(x: int, y: int):
	for enemy: Enemy in enemies:
		if enemy.map_x == x and enemy.map_y == y:
			return enemy
	return null


# Returns the Item at (x, y), or null
func _item_at(x: int, y: int):
	for item: Item in items:
		if item.map_x == x and item.map_y == y:
			return item
	return null
