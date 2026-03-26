class_name Enemy extends Entity

var hp: int
var hp_max: int
var enemy_type: String


func _init(x: int, y: int, p_enemy_type: String) -> void:
	var g: String
	var c: String
	var n: String
	var h: int
	match p_enemy_type:
		"cheese_golem":
			g = "g"; c = "#FFD700"; n = "Cheese Golem"; h = 8
		"ice_troll":
			g = "T"; c = "#ADD8E6"; n = "Ice Troll"; h = 12
		"bar_brawler":
			g = "b"; c = "#8B4513"; n = "Bar Brawler"; h = 6
		_:
			g = "?"; c = "#FF00FF"; n = "Unknown"; h = 5
	super(x, y, g, c, n)
	enemy_type = p_enemy_type
	hp_max = h
	hp = hp_max


func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)


func is_dead() -> bool:
	return hp <= 0


# No-op stub — AI will be added in a future iteration
func act(_game_state: Dictionary) -> void:
	pass
