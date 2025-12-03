extends Node

var _selected_ship := {
	"id": "",
	"name": "",
	"type": "",
	"texture": "",
}

func set_selected_ship(ship_id: String, ship_name: String = "", ship_texture: String = "", ship_type: String = "") -> void:
	_selected_ship.id = ship_id
	if not ship_name.is_empty():
		_selected_ship.name = ship_name
	if not ship_type.is_empty():
		_selected_ship.type = ship_type
	if not ship_texture.is_empty():
		_selected_ship.texture = ship_texture

func apply_ship_data(data: Dictionary) -> void:
	var ship_id: String = str(data.get("ship_id", ""))
	_selected_ship.id = ship_id
	_selected_ship.name = str(data.get("ship_name", ""))
	_selected_ship.type = str(data.get("ship_type", ""))
	_selected_ship.texture = str(data.get("ship_texture", ""))

func clear_selected_ship() -> void:
	_selected_ship = {
		"id": "",
		"name": "",
		"type": "",
		"texture": "",
	}

func get_selected_ship_id() -> String:
	return str(_selected_ship.id)

func get_selected_ship_name() -> String:
	return str(_selected_ship.name)

func get_selected_ship_type() -> String:
	return str(_selected_ship.type)

func get_selected_ship_texture() -> String:
	return str(_selected_ship.texture)

func get_selected_ship_data() -> Dictionary:
	return _selected_ship.duplicate(true)
