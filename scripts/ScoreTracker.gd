extends Node

signal score_changed(value: int)
signal high_score_changed(value: int)

var score: int = 0
var high_score: int = 0
var score_multiplier: float = 1.0
var combo_count: int = 0
var combo_timer: Timer

# Score values for different actions
const ENEMY_KILL_SCORE = 100
const MOTHERSHIP_KILL_SCORE = 500
const SCOUT_KILL_SCORE = 50
const COIN_PICKUP_VALUE = 10
const LEVEL_UP_BONUS = 1000

func _ready():
	add_to_group("score_tracker")
	_load_high_score()
	_setup_combo_timer()
	print("ScoreTracker: Initialized with high score: ", high_score)

func _setup_combo_timer():
	combo_timer = Timer.new()
	combo_timer.wait_time = 2.0  # 2 seconds to maintain combo
	combo_timer.one_shot = true
	combo_timer.timeout.connect(_reset_combo)
	add_child(combo_timer)

func add_score(amount: int, use_multiplier: bool = true):
	var actual_amount = amount
	if use_multiplier:
		actual_amount = int(amount * score_multiplier)
	
	score += actual_amount
	_emit_score_update()
	
	# Update combo
	combo_count += 1
	combo_timer.start()
	
	print("ScoreTracker: Added ", actual_amount, " points (combo: x", combo_count, ")")
	return actual_amount

func add_enemy_kill(enemy_type: String):
	var points = ENEMY_KILL_SCORE
	
	match enemy_type.to_lower():
		"mothership":
			points = MOTHERSHIP_KILL_SCORE
		"scout":
			points = SCOUT_KILL_SCORE
		"enemy":
			points = ENEMY_KILL_SCORE
		_:
			points = ENEMY_KILL_SCORE
	
	return add_score(points)

func add_coin_pickup():
	return add_score(COIN_PICKUP_VALUE, false)  # Coins don't use multiplier

func add_level_up_bonus():
	return add_score(LEVEL_UP_BONUS, false)

func set_score_multiplier(multiplier: float):
	score_multiplier = multiplier
	print("ScoreTracker: Score multiplier set to ", multiplier)

func get_score() -> int:
	return score

func get_high_score() -> int:
	return high_score

func get_combo_count() -> int:
	return combo_count

func reset_score():
	if score > high_score:
		high_score = score
		_save_high_score()
		high_score_changed.emit(high_score)
	
	score = 0
	_reset_combo()
	_emit_score_update()
	print("ScoreTracker: Score reset")

func _reset_combo():
	combo_count = 0
	score_multiplier = 1.0

func _emit_score_update():
	score_changed.emit(score)
	
	# Check for high score
	if score > high_score:
		high_score = score
		_save_high_score()
		high_score_changed.emit(high_score)

func _load_high_score():
	# In a real implementation, this would load from a save file
	# For now, we'll use a simple file-based approach
	var file = FileAccess.open("user://high_score.save", FileAccess.READ)
	if file:
		high_score = file.get_32()
		file.close()
	else:
		high_score = 0

func _save_high_score():
	# Save high score to file
	var file = FileAccess.open("user://high_score.save", FileAccess.WRITE)
	if file:
		file.store_32(high_score)
		file.close()

func get_score_with_combo() -> String:
	if combo_count > 1:
		return str(score) + " (x" + str(combo_count) + ")"
	return str(score)
