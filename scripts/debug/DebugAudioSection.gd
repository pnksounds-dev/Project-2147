extends "res://scripts/DebugSection.gd"
class_name DebugAudioSection

var audio_manager: Node
var volume_slider: HSlider
var volume_label: Label

func _init():
	super("Audio")

func get_debug_content() -> Control:
	# Find audio manager
	if Engine.get_main_loop():
		var tree = Engine.get_main_loop() as SceneTree
		if tree:
			audio_manager = tree.get_first_node_in_group("audio_manager")
			if not audio_manager:
				audio_manager = tree.root.get_node_or_null("/root/AudioManager")
	
	var container = create_container(true, 6)
	
	# Status
	var status = create_section("Status")
	var audio_info = create_label("Audio: " + ("OK" if audio_manager else "N/A"), Color.GREEN if audio_manager else Color.RED)
	status.add_child(audio_info)
	container.add_child(status)
	
	# Volume control - compact
	var vol_section = create_section("Volume")
	var vol_row = create_container(false, 4)
	volume_slider = create_slider(0, 100, 70, 5)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.value_changed.connect(_on_volume_changed)
	vol_row.add_child(volume_slider)
	volume_label = create_label("70%")
	vol_row.add_child(volume_label)
	vol_section.add_child(vol_row)
	container.add_child(vol_section)
	
	# Sound tests - compact row
	var sounds = create_section("Test Sounds")
	var btn_row = create_container(false, 4)
	btn_row.add_child(create_button("Bullet", func(): _play_sound("bullet")))
	btn_row.add_child(create_button("Phaser", func(): _play_sound("phaser")))
	btn_row.add_child(create_button("Click", func(): _play_sound("button")))
	sounds.add_child(btn_row)
	container.add_child(sounds)
	
	return container

func _on_volume_changed(value: float):
	if volume_label:
		volume_label.text = "%d%%" % int(value)
	if audio_manager and audio_manager.has_method("set_master_volume"):
		audio_manager.set_master_volume(value / 100.0)

func _play_sound(sound_type: String):
	if not audio_manager:
		log_message("No audio manager")
		return
	match sound_type:
		"bullet":
			if audio_manager.has_method("play_bullet_fire"):
				audio_manager.play_bullet_fire()
		"phaser":
			if audio_manager.has_method("play_paser_beams"):
				audio_manager.play_paser_beams()
		"button":
			if audio_manager.has_method("play_button_click"):
				audio_manager.play_button_click()
	log_message("Played: " + sound_type)
