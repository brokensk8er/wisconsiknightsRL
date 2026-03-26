class_name Player extends Entity

var hp: int
var hp_max: int
var inventory: Array  # Array of Item
var identified: Dictionary  # effect (String) -> bool


func _init(x: int, y: int) -> void:
	super(x, y, "@", "#FF0000", "You")
	hp_max = 30
	hp = hp_max
	inventory = []
	identified = {}


func pickup_item(item: Item) -> void:
	inventory.append(item)


func identify(effect: String) -> void:
	identified[effect] = true


func is_identified(effect: String) -> bool:
	return identified.get(effect, false)


func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)


func heal(amount: int) -> void:
	hp = min(hp_max, hp + amount)


func is_dead() -> bool:
	return hp <= 0
