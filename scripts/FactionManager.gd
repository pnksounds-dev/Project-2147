extends Node

class_name FactionManager

# Faction IDs
const FACTION_PLAYER = "player"
const FACTION_ENEMY = "enemy"
const FACTION_NEUTRAL = "neutral"
const FACTION_TRADER = "trader"

# Faction Colors
const FACTION_COLORS = {
	FACTION_PLAYER: Color(0.0, 0.8, 1.0), # Cyan/Blue
	FACTION_ENEMY: Color(1.0, 0.2, 0.2),  # Red
	FACTION_NEUTRAL: Color(0.8, 0.8, 0.8), # Gray
	FACTION_TRADER: Color(1.0, 0.8, 0.2)   # Gold/Orange
}

# Faction Names
const FACTION_NAMES = {
	FACTION_PLAYER: "Alliance",
	FACTION_ENEMY: "The Swarm",
	FACTION_NEUTRAL: "Independent",
	FACTION_TRADER: "Trade Guild"
}

static var instance: FactionManager

func _init() -> void:
	if not instance:
		instance = self

func _ready() -> void:
	add_to_group("faction_manager")
	print("FactionManager: Initialized")

func get_faction_color(faction_id: String) -> Color:
	return FACTION_COLORS.get(faction_id, Color.WHITE)

func get_faction_name(faction_id: String) -> String:
	return FACTION_NAMES.get(faction_id, "Unknown")

func is_enemy(faction_a: String, faction_b: String) -> bool:
	if faction_a == faction_b: return false
	if faction_a == FACTION_NEUTRAL or faction_b == FACTION_NEUTRAL: return false
	
	# Traders are friendly to players
	if faction_a == FACTION_TRADER and faction_b == FACTION_PLAYER: return false
	if faction_a == FACTION_PLAYER and faction_b == FACTION_TRADER: return false
	
	return true # Default to hostile for different factions
