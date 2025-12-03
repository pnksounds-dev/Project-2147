extends Node

var score = 0
var current_biome = "Space"

func _ready():
	GameLog.log_system("GameManager initialized")

func add_score(amount):
	score += amount
	GameLog.log_economy("Score added: %d, New Score: %d" % [amount, score])
