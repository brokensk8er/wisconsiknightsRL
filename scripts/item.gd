class_name Item extends Entity

var item_kind: String   # "potion" or "scroll"
var effect: String      # internal effect key e.g. "heal", "teleport"
var appearance: String  # what the player sees before identification
var appearance_color: String

# True names shown after identification
const TRUE_NAMES: Dictionary = {
	"heal":       "Potion of Healing",
	"poison":     "Potion of Poison",
	"full_heal":  "Potion of Full Healing",
	"map_reveal": "Potion of Cartography",
	"speed":      "Potion of Speed",
	"confusion":  "Potion of Confusion",
	"identify":   "Scroll of Identify",
	"teleport":   "Scroll of Teleportation",
	"light":      "Scroll of Light",
	"fire":       "Scroll of Fire",
}


func _init(x: int, y: int, p_effect: String, p_appearance: String,
		p_appearance_color: String, p_kind: String) -> void:
	var g := "!" if p_kind == "potion" else "?"
	super(x, y, g, p_appearance_color, p_appearance)
	item_kind = p_kind
	effect = p_effect
	appearance = p_appearance
	appearance_color = p_appearance_color


func display_name(player: Player) -> String:
	if player.is_identified(effect):
		return TRUE_NAMES.get(effect, appearance)
	return appearance


# Returns a Dictionary with keys:
#   "message": String  — log message
#   "effect":  String  — the effect key (so game.gd can handle side-effects)
func use(player: Player) -> Dictionary:
	player.identify(effect)
	match effect:
		"heal":
			player.heal(10)
			return {message = "You drink the %s. You feel better." % appearance,
					effect = effect}
		"poison":
			player.take_damage(5)
			return {message = "You drink the %s. It burns!" % appearance,
					effect = effect}
		"full_heal":
			player.heal(player.hp_max)
			return {message = "You drink the %s. Warmth floods through you." % appearance,
					effect = effect}
		"map_reveal":
			return {message = "You drink the %s. The world becomes clear." % appearance,
					effect = effect}
		"speed":
			return {message = "You drink the %s. You feel swift!" % appearance,
					effect = effect}
		"confusion":
			return {message = "You drink the %s. Your mind swims..." % appearance,
					effect = effect}
		"identify":
			return {message = "You read the %s. Knowledge flows into you." % appearance,
					effect = effect}
		"teleport":
			return {message = "You read the %s. The world lurches!" % appearance,
					effect = effect}
		"light":
			return {message = "You read the %s. The dungeon brightens." % appearance,
					effect = effect}
		"fire":
			return {message = "You read the %s. It bursts into flame!" % appearance,
					effect = effect}
	return {message = "Nothing happens.", effect = effect}
