extends Node

# Singleton instance
static var instance: Node
signal system_ready

# Audio bus indices
enum Bus { MASTER, MUSIC, SFX, UI }

# Audio player nodes
var _music_player: AudioStreamPlayer

# Audio player pools for simultaneous sounds
var _sfx_players: Array[AudioStreamPlayer] = []
var _ui_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS: int = 20  # Support up to 20 simultaneous SFX
const MAX_UI_PLAYERS: int = 10   # Support up to 10 simultaneous UI sounds

# Audio stream resources
var _audio_streams: Dictionary = {}

func _ready() -> void:
	print("AudioManager: _ready called")
	
	# Set up singleton
	if instance == null:
		instance = self
		print("AudioManager: Singleton instance set")
	else:
		print("AudioManager: Singleton already exists, freeing this instance")
		queue_free()
		return
	
	# Ensure this AudioManager can be located via group lookups
	add_to_group("audio_manager")
	
	# Create audio players programmatically since autoloads don't have scene files
	_create_audio_players()
	
	print("AudioManager: Initialized")

func _create_audio_players() -> void:
	"""Create audio player nodes programmatically"""
	# Create music player
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	
	# Create SFX players pool
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer" + str(i)
		add_child(player)
		_sfx_players.append(player)
	
	# Create UI players pool
	for i in range(MAX_UI_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.name = "UIPlayer" + str(i)
		add_child(player)
		_ui_players.append(player)

# Volume settings - set to 100% (1.0) by default
var _music_volume: float = 1.0
var _sfx_volume: float = 1.0
var _ui_volume: float = 1.0

# Pitch variation settings
var _bullet_pitch_min: float = 0.9
var _bullet_pitch_max: float = 1.1

var initialized: bool = false

# Don't auto-initialize in _ready - let loading screen handle it

func initialize() -> void:
	"""Initialize audio system for loading screen"""
	print("AudioManager: Initializing...")
	
	# Load audio streams
	_load_audio_streams()
	
	# Set up audio buses
	_setup_audio_buses()
	
	# Create audio player pools
	_create_audio_pools()
	
	# Connect music player finished signal for looping
	_music_player.finished.connect(_on_music_finished)
	
	initialized = true
	system_ready.emit()
	print("AudioManager: Initialization complete")

func _load_audio_streams() -> void:
	# Music tracks
	_audio_streams["music_bounce_orbits"] = load("res://assets/Audio/music/BounceOfTheOrbits.wav")
	_audio_streams["music_choir_gas"] = load("res://assets/Audio/music/ChoirOfTheGas.wav")
	_audio_streams["music_explorer_void"] = load("res://assets/Audio/music/ExplorerOfTheVoid.wav")
	_audio_streams["music_orb_collector"] = load("res://assets/Audio/music/OrbCollectorSpaceTheme.wav")
	
	# Weapon sounds
	_audio_streams["weapon_ballistic_barrage"] = load("res://assets/Audio/weapons/BallisticBarrage.wav")
	_audio_streams["weapon_bullet_1"] = load("res://assets/Audio/weapons/BulletSound1.wav")
	_audio_streams["weapon_bullet_2"] = load("res://assets/Audio/weapons/BulletSound2.wav")
	_audio_streams["weapon_bullet_3"] = load("res://assets/Audio/weapons/BulletSound3.wav")
	_audio_streams["weapon_bullet_4"] = load("res://assets/Audio/weapons/BulletSound4.wav")
	_audio_streams["weapon_photon_torpedo"] = load("res://assets/Audio/weapons/PhotonTorpedoLaunch.wav")
	_audio_streams["weapon_phaser_beams"] = load("res://assets/Audio/weapons/PhaserBeams.wav")
	_audio_streams["weapon_explosion_1"] = load("res://assets/Audio/weapons/explosion1.wav")
	
	# UI sounds
	_audio_streams["ui_notification"] = load("res://assets/Audio/ui/Notification.wav")
	_audio_streams["ui_button_click"] = load("res://assets/Audio/ui/Ui_Button_Click.wav")
	_audio_streams["ui_radar_beep"] = load("res://assets/Audio/ui/Radar Beep.wav")
	_audio_streams["ui_text_noise"] = load("res://assets/Audio/ui/TextNoise.wav")
	_audio_streams["ui_dripping_sounds"] = load("res://assets/Audio/ui/main_menu/DrippingSounds.wav")
	_audio_streams["ui_florescen_light"] = load("res://assets/Audio/ui/main_menu/FlorescenLightSounds.wav")
	_audio_streams["ui_sound"] = load("res://assets/Audio/ui/ui sound.wav")
	
	# Player sounds
	_audio_streams["player_death"] = load("res://assets/Audio/player/Death.wav")
	_audio_streams["player_shield_fail"] = load("res://assets/Audio/player/ShipShieldFail.wav")
	_audio_streams["player_ark"] = load("res://assets/Audio/player/Ark.wav")
	_audio_streams["player_ship_alarm"] = load("res://assets/Audio/player/Ship Alarm 1.wav")
	_audio_streams["player_warp_sound"] = load("res://assets/Audio/player/WarpSound.wav")
	
	# Orb sounds
	_audio_streams["orb_pickup"] = load("res://assets/Audio/orb/OrbPickUpSound.wav")
	
	# Event sounds
	_audio_streams["event_wormhole"] = load("res://assets/Audio/event/WormholeSound.wav")
	_audio_streams["event_leaving_warp"] = load("res://assets/Audio/event/LeavingWarp_wormhole.wav")
	
	# Ship sounds
	_audio_streams["ship_warp_jump"] = load("res://assets/Audio/ship_warp_jump.wav")
	_audio_streams["ship_warp_land"] = load("res://assets/Audio/ship_warp_land.wav")
	
	print("AudioManager: Loaded ", _audio_streams.size(), " audio streams")

func _setup_audio_buses() -> void:
	# Create audio buses if they don't exist
	# We need 4 buses total: MASTER (0), MUSIC (1), SFX (2), UI (3)
	# MASTER already exists, so we need to create 3 more
	var current_bus_count = AudioServer.get_bus_count()
	var needed_buses = 4
	if current_bus_count < needed_buses:
		for i in range(current_bus_count, needed_buses):
			AudioServer.add_bus()
	
	# Set bus names (skip MASTER as it's already named correctly)
	AudioServer.set_bus_name(Bus.MUSIC, "Music")
	AudioServer.set_bus_name(Bus.SFX, "SFX")
	AudioServer.set_bus_name(Bus.UI, "UI")
	
	# Set initial volumes
	_update_bus_volumes()

func _update_bus_volumes() -> void:
	# Set all buses to 100% volume (with safety checks)
	if AudioServer.get_bus_count() > Bus.MASTER:
		AudioServer.set_bus_volume_db(Bus.MASTER, linear_to_db(1.0))
	if AudioServer.get_bus_count() > Bus.MUSIC:
		AudioServer.set_bus_volume_db(Bus.MUSIC, linear_to_db(_music_volume))
	if AudioServer.get_bus_count() > Bus.SFX:
		AudioServer.set_bus_volume_db(Bus.SFX, linear_to_db(_sfx_volume))
	if AudioServer.get_bus_count() > Bus.UI:
		AudioServer.set_bus_volume_db(Bus.UI, linear_to_db(_ui_volume))
	
	print("AudioManager: Set volumes - MASTER: 100%, MUSIC: ", _music_volume * 100, "%, SFX: ", _sfx_volume * 100, "%, UI: ", _ui_volume * 100, "%")

# Music playback
func play_music(music_name: String, loop: bool = true) -> void:
	var stream_key = "music_" + music_name
	if _audio_streams.has(stream_key):
		_music_player.stream = _audio_streams[stream_key]
		
		# Set loop mode for different stream types
		if _music_player.stream is AudioStreamWAV:
			_music_player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		elif _music_player.stream is AudioStreamMP3:
			_music_player.stream.loop = loop
		
		_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func set_music_volume(volume: float) -> void:
	_music_volume = clamp(volume, 0.0, 1.0)
	if AudioServer.get_bus_count() > Bus.MUSIC:
		AudioServer.set_bus_volume_db(Bus.MUSIC, linear_to_db(_music_volume))

func set_sfx_volume(volume: float) -> void:
	_sfx_volume = clamp(volume, 0.0, 1.0)
	if AudioServer.get_bus_count() > Bus.SFX:
		AudioServer.set_bus_volume_db(Bus.SFX, linear_to_db(_sfx_volume))

func set_ui_volume(volume: float) -> void:
	_ui_volume = clamp(volume, 0.0, 1.0)
	if AudioServer.get_bus_count() > Bus.UI:
		AudioServer.set_bus_volume_db(Bus.UI, linear_to_db(_ui_volume))

# SFX playback with pooling
func play_sfx(sfx_name: String, pitch_scale: float = 1.0) -> void:
	var stream_key = "weapon_" + sfx_name
	if not _audio_streams.has(stream_key):
		stream_key = sfx_name  # Try without prefix
	
	if _audio_streams.has(stream_key):
		var player = _get_available_sfx_player()
		if player:
			player.stream = _audio_streams[stream_key]
			player.pitch_scale = pitch_scale
			player.play()
	else:
		print("AudioManager: ERROR - Stream not found: ", stream_key)

func play_explosion(explosion_id: int = 1) -> void:
	var stream_key = "weapon_explosion_" + str(explosion_id)
	if _audio_streams.has(stream_key):
		var player = _get_available_sfx_player()
		if player:
			player.stream = _audio_streams[stream_key]
			player.pitch_scale = 1.0
			player.play()

# Play bullet sound with random variation
func play_bullet_sound() -> void:
	var bullet_sounds = ["weapon_bullet_1", "weapon_bullet_2", "weapon_bullet_3", "weapon_bullet_4"]
	var random_sound = bullet_sounds[randi() % bullet_sounds.size()]
	var random_pitch = randf_range(_bullet_pitch_min, _bullet_pitch_max)
	play_sfx(random_sound, random_pitch)

# Play phaser beam sound
func play_phaser_beam() -> void:
	play_sfx("weapon_phaser_beams", 1.0)

# UI sound playback with pooling
func play_ui_sound(ui_sound_name: String) -> void:
	var stream_key = "ui_" + ui_sound_name
	if _audio_streams.has(stream_key):
		var player = _get_available_ui_player()
		if player:
			player.stream = _audio_streams[stream_key]
			player.pitch_scale = 1.0
			player.play()

func play_button_click() -> void:
	play_ui_sound("button_click")

func play_notification() -> void:
	play_ui_sound("notification")

# Player sounds
func play_player_sound(sound_name: String) -> void:
	var stream_key = "player_" + sound_name
	if _audio_streams.has(stream_key):
		var player = _get_available_sfx_player()
		if player:
			player.stream = _audio_streams[stream_key]
			player.pitch_scale = 1.0
			player.play()

func play_player_death() -> void:
	play_player_sound("death")

func play_shield_fail() -> void:
	play_player_sound("shield_fail")

# Orb sounds
func play_orb_pickup() -> void:
	if _audio_streams.has("orb_pickup"):
		var player = _get_available_sfx_player()
		if player:
			player.stream = _audio_streams["orb_pickup"]
			player.pitch_scale = 1.0
			player.play()

# Event sounds
func play_wormhole() -> void:
	if _audio_streams.has("event_wormhole"):
		var player = _get_available_sfx_player()
		if player:
			player.stream = _audio_streams["event_wormhole"]
			player.pitch_scale = 1.0
			player.play()

# Master volume control
func set_master_volume(volume: float) -> void:
	var clamped_volume = clamp(volume, 0.0, 1.0)
	AudioServer.set_bus_volume_db(Bus.MASTER, linear_to_db(clamped_volume))

func get_master_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(Bus.MASTER))

func get_music_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(Bus.MUSIC))

func get_sfx_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(Bus.SFX))

func get_ui_volume() -> float:
	return db_to_linear(AudioServer.get_bus_volume_db(Bus.UI))

# Helper functions
func _on_music_finished() -> void:
	# Loop music if it's supposed to loop
	if _music_player.stream:
		var should_loop = false
		if _music_player.stream is AudioStreamWAV:
			should_loop = _music_player.stream.loop_mode != AudioStreamWAV.LOOP_DISABLED
		elif _music_player.stream is AudioStreamMP3:
			should_loop = _music_player.stream.loop
		
		if should_loop:
			_music_player.play()

func get_available_music_tracks() -> Array[String]:
	var tracks: Array[String] = []
	for key in _audio_streams.keys():
		if key.begins_with("music_"):
			tracks.append(key.replace("music_", ""))
	return tracks

func get_available_sfx() -> Array[String]:
	var sfx_list: Array[String] = []
	for key in _audio_streams.keys():
		if key.begins_with("weapon_") or key.begins_with("player_") or key.begins_with("orb_") or key.begins_with("event_"):
			sfx_list.append(key)
	return sfx_list

func get_available_ui_sounds() -> Array[String]:
	var ui_sounds: Array[String] = []
	for key in _audio_streams.keys():
		if key.begins_with("ui_"):
			ui_sounds.append(key.replace("ui_", ""))
	return ui_sounds

# Audio player pool management
func _create_audio_pools() -> void:
	# Create SFX player pool
	for i in range(MAX_SFX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_" + str(i)
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)
	
	# Create UI player pool
	for i in range(MAX_UI_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.name = "UIPlayer_" + str(i)
		player.bus = "UI"
		add_child(player)
		_ui_players.append(player)
	
	print("AudioManager: Created ", MAX_SFX_PLAYERS, " SFX players and ", MAX_UI_PLAYERS, " UI players")

func _get_available_sfx_player() -> AudioStreamPlayer:
	# Find a player that's not currently playing
	for player in _sfx_players:
		if not player.playing:
			return player
	# If all players are busy, return the first one (will interrupt)
	return _sfx_players[0] if _sfx_players.size() > 0 else null

func _get_available_ui_player() -> AudioStreamPlayer:
	# Find a player that's not currently playing
	for player in _ui_players:
		if not player.playing:
			return player
	# If all players are busy, return the first one (will interrupt)
	return _ui_players[0] if _ui_players.size() > 0 else null
