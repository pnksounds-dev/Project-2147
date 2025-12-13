extends Node

# Unified item data structure
var unified_items: Dictionary = {}
var item_id_mappings: Dictionary = {} # Legacy ID -> Unified ID

signal item_catalog_ready

func _ready() -> void:
	_build_catalog()
	item_catalog_ready.emit()

func _build_catalog() -> void:
	unified_items.clear()
	item_id_mappings.clear()
	_ingest_item_database()
	_ingest_item_registry()
	_print_catalog_summary()

func _print_catalog_summary() -> void:
	# Lightweight debug helper to confirm catalog contents
	print("ItemCatalog: unified_items=", unified_items.size())

func _ingest_item_database() -> void:
	var item_db = get_tree().get_first_node_in_group("item_database")
	if item_db == null:
		item_db = get_node_or_null("/root/ItemDatabase")
	if item_db == null or not item_db.has_method("get_all_items"):
		return
	var all_items: Dictionary = item_db.get_all_items()
	for item_id in all_items.keys():
		var item = all_items[item_id]
		if item == null:
			continue
		var unified_id = _register_unified_id(item_id)
		var entry: Dictionary = unified_items.get(unified_id, {})
		entry["id"] = unified_id
		entry["legacy_ids"] = (entry.get("legacy_ids", []) as Array) + [item_id]
		entry["source"] = "ItemDatabase"
		entry["category"] = item.get("category", "")
		entry["rarity"] = item.get("rarity", "common")
		entry["display_name"] = item.get("display_name", item_id)
		entry["description"] = item.get("description", "")
		entry["base_price"] = int(item.get("value", 0))
		entry["weight"] = float(item.get("weight", 0.0))
		entry["icon"] = item.get("icon", null)
		entry["icon_path"] = item.get("icon_path", "")
		entry["data_ref"] = item
		unified_items[unified_id] = entry

func _ingest_item_registry() -> void:
	var registry = get_node_or_null("/root/ItemRegistry")
	if registry == null:
		registry = get_tree().get_first_node_in_group("item_registry")
	if registry == null:
		return
	if registry.has_method("get_all_items"):
		var reg_items: Dictionary = registry.get_all_items()
		for item_id in reg_items.keys():
			var item_data = reg_items[item_id]
			if item_data == null:
				continue
			var unified_id = _register_unified_id(item_id)
			var entry: Dictionary = unified_items.get(unified_id, {})
			entry["id"] = unified_id
			var legacy_ids: Array = entry.get("legacy_ids", [])
			if not legacy_ids.has(item_id):
				legacy_ids.append(item_id)
			entry["legacy_ids"] = legacy_ids
			entry["source_registry"] = true
			entry["registry_data"] = item_data
			if not entry.has("display_name"):
				entry["display_name"] = item_data.get("name", item_id)
			if not entry.has("description"):
				entry["description"] = item_data.get("description", "")
			if not entry.has("category"):
				entry["category"] = item_data.get("type", "")
			if not entry.has("base_price"):
				entry["base_price"] = int(item_data.get("base_value", 0))
			unified_items[unified_id] = entry
	if registry.has_method("get_all_weapons"):
		var reg_weapons: Dictionary = registry.get_all_weapons()
		for weapon_id in reg_weapons.keys():
			var weapon_data = reg_weapons[weapon_id]
			if weapon_data == null:
				continue
			var unified_id = _register_unified_id(weapon_id)
			var entry: Dictionary = unified_items.get(unified_id, {})
			entry["id"] = unified_id
			var legacy_weapon_ids: Array = entry.get("legacy_ids", [])
			if not legacy_weapon_ids.has(weapon_id):
				legacy_weapon_ids.append(weapon_id)
			entry["legacy_ids"] = legacy_weapon_ids
			entry["source_registry_weapon"] = true
			entry["registry_weapon_data"] = weapon_data
			if not entry.has("category"):
				entry["category"] = "weapon"
			unified_items[unified_id] = entry

func _register_unified_id(source_id: String) -> String:
	var unified_id = source_id
	item_id_mappings[source_id] = unified_id
	if not unified_items.has(unified_id):
		unified_items[unified_id] = {}
	return unified_id

# Backward compatibility helpers

func get_item_legacy(item_id: String) -> Dictionary:
	var unified_id = normalize_item_id(item_id)
	return unified_items.get(unified_id, {})

func get_item_registry(item_id: String) -> ItemData:
	var registry = get_node_or_null("/root/ItemRegistry")
	if registry and registry.has_method("get_item"):
		return registry.get_item(item_id)
	return null

func normalize_item_id(legacy_id: String) -> String:
	return item_id_mappings.get(legacy_id, legacy_id)

# Core integration API

func get_unified_item(item_id: String) -> Dictionary:
	var unified_id = normalize_item_id(item_id)
	return unified_items.get(unified_id, {})

func get_items_by_category(category: String) -> Array:
	var results: Array = []
	var target = category.to_lower()
	for item in unified_items.values():
		var cat = String(item.get("category", "")).to_lower()
		if cat == target:
			results.append(item)
	return results

func get_price_base(item_id: String) -> int:
	var item = get_unified_item(item_id)
	return int(item.get("base_price", 0))

func validate_item_id(item_id: String) -> bool:
	var unified_id = normalize_item_id(item_id)
	return unified_items.has(unified_id)

func get_item_display_info(item_id: String) -> Dictionary:
	var item = get_unified_item(item_id)
	if item.is_empty():
		return {}
	return {
		"id": item.get("id", ""),
		"display_name": item.get("display_name", ""),
		"description": item.get("description", ""),
		"icon": item.get("icon", null),
		"icon_path": item.get("icon_path", ""),
		"category": item.get("category", ""),
		"rarity": item.get("rarity", "common")
	}

func get_all_items() -> Array:
	return unified_items.values()

func search_items(query: String) -> Array:
	var q = query.to_lower()
	var results: Array = []
	for item in unified_items.values():
		var id = String(item.get("id", "")).to_lower()
		var display_name = String(item.get("display_name", "")).to_lower()
		var desc = String(item.get("description", "")).to_lower()
		if id.contains(q) or display_name.contains(q) or desc.contains(q):
			results.append(item)
	return results

func get_item_categories() -> Array:
	var categories: Dictionary = {}
	for item in unified_items.values():
		var cat = String(item.get("category", ""))
		if not cat.is_empty():
			categories[cat] = true
	return categories.keys()
