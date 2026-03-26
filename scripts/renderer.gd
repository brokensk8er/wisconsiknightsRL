class_name Renderer

const VIEWPORT_COLS := 64
const VIEWPORT_ROWS := 29  # row 29 reserved for status line

const COLOR_FLOOR_VIS  := "#5C4A1E"
const COLOR_FLOOR_MEM  := "#2A2010"
const COLOR_WALL_VIS   := "#8B7355"
const COLOR_WALL_MEM   := "#3D3020"
const COLOR_UNSEEN     := "#111111"
const COLOR_STATUS     := "#CCCCCC"
const COLOR_LOG        := "#AAAAAA"
const COLOR_HP_GOOD    := "#44FF44"
const COLOR_HP_HURT    := "#FFFF44"
const COLOR_HP_LOW     := "#FF4444"

var cam_x: int = 0
var cam_y: int = 0


func update_camera(player_x: int, player_y: int, map_w: int, map_h: int) -> void:
	cam_x = clampi(player_x - VIEWPORT_COLS / 2, 0, max(0, map_w - VIEWPORT_COLS))
	cam_y = clampi(player_y - VIEWPORT_ROWS / 2, 0, max(0, map_h - VIEWPORT_ROWS))


# Returns a BBCode string for the full 640×480 display.
func render(map: GameMap, fov: FOV, player: Player,
			enemies: Array, items: Array,
			log_message: String) -> String:
	# Build a 2D grid of [char, color] pairs
	# grid[row][col] = {c: String, color: String}
	var grid: Array = []
	for _r in range(VIEWPORT_ROWS):
		var row: Array = []
		for _c in range(VIEWPORT_COLS):
			row.append({c = " ", color = COLOR_UNSEEN})
		grid.append(row)

	# 1. Tiles
	for screen_y in range(VIEWPORT_ROWS):
		for screen_x in range(VIEWPORT_COLS):
			var mx := cam_x + screen_x
			var my := cam_y + screen_y
			var tile := map.get_tile(mx, my)
			if fov.is_visible(mx, my):
				if tile == GameMap.TILE_FLOOR:
					grid[screen_y][screen_x] = {c = ".", color = COLOR_FLOOR_VIS}
				else:
					grid[screen_y][screen_x] = {c = "#", color = COLOR_WALL_VIS}
			elif fov.is_explored(mx, my):
				if tile == GameMap.TILE_FLOOR:
					grid[screen_y][screen_x] = {c = ".", color = COLOR_FLOOR_MEM}
				else:
					grid[screen_y][screen_x] = {c = "#", color = COLOR_WALL_MEM}

	# 2. Items (only if visible)
	for item: Item in items:
		var sx := item.map_x - cam_x
		var sy := item.map_y - cam_y
		if sx >= 0 and sx < VIEWPORT_COLS and sy >= 0 and sy < VIEWPORT_ROWS:
			if fov.is_visible(item.map_x, item.map_y):
				grid[sy][sx] = {c = item.glyph, color = item.color}

	# 3. Enemies (only if visible)
	for enemy: Enemy in enemies:
		var sx := enemy.map_x - cam_x
		var sy := enemy.map_y - cam_y
		if sx >= 0 and sx < VIEWPORT_COLS and sy >= 0 and sy < VIEWPORT_ROWS:
			if fov.is_visible(enemy.map_x, enemy.map_y):
				grid[sy][sx] = {c = enemy.glyph, color = enemy.color}

	# 4. Player (always visible)
	var px := player.map_x - cam_x
	var py := player.map_y - cam_y
	if px >= 0 and px < VIEWPORT_COLS and py >= 0 and py < VIEWPORT_ROWS:
		grid[py][px] = {c = "@", color = player.color}

	# 5. Serialize grid to BBCode
	var lines: PackedStringArray = []
	for row in grid:
		lines.append(_row_to_bbcode(row))

	# 6. Status line
	lines.append(_build_status_line(player, log_message))

	return "\n".join(lines)


func _row_to_bbcode(row: Array) -> String:
	# Run-length encode by color to minimize BBCode tag count
	var result := ""
	var run_color := ""
	var run_chars := ""

	for cell in row:
		if cell.color == run_color:
			run_chars += cell.c
		else:
			if run_chars != "":
				result += "[color=%s]%s[/color]" % [run_color, run_chars]
			run_color = cell.color
			run_chars = cell.c

	if run_chars != "":
		result += "[color=%s]%s[/color]" % [run_color, run_chars]

	return result


func _build_status_line(player: Player, log_message: String) -> String:
	var hp_color: String
	var hp_frac := float(player.hp) / float(player.hp_max)
	if hp_frac > 0.6:
		hp_color = COLOR_HP_GOOD
	elif hp_frac > 0.3:
		hp_color = COLOR_HP_HURT
	else:
		hp_color = COLOR_HP_LOW

	var hp_text := "[color=%s]HP:%d/%d[/color]" % [hp_color, player.hp, player.hp_max]
	var log_text := ""
	if log_message != "":
		log_text = "  [color=%s]%s[/color]" % [COLOR_LOG, log_message]

	return "[color=%s]─────────────────────────────────────────────────────────────────[/color]\n%s%s" \
		% [COLOR_STATUS, hp_text, log_text]
