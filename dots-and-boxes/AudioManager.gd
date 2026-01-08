extends Node

var music_player : AudioStreamPlayer
var sfx_player : AudioStreamPlayer

# --- LOAD ASSETS ---
# Ensure these paths match your files exactly
var bg_music = preload("res://ASSETS/Background Music.wav")
var click_sound = preload("res://ASSETS/Click(PenSound).wav")

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS # Keep running even if game pauses
	
	# Create players dynamically
	music_player = AudioStreamPlayer.new()
	sfx_player = AudioStreamPlayer.new()
	
	add_child(music_player)
	add_child(sfx_player)
	
	# Setup and Play Music
	if bg_music:
		music_player.stream = bg_music
		music_player.volume_db = -5.0 # Normal Volume (Menu)
		music_player.play()
	
	if click_sound:
		sfx_player.stream = click_sound

# Function to play click sound
func play_click():
	if sfx_player.stream:
		sfx_player.pitch_scale = randf_range(0.9, 1.1)
		sfx_player.play()

# Lower volume when entering the Game
func set_volume_low():
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -15.0, 1.0)

# Reset volume when going back to Menu
func set_volume_normal():
	var tween = create_tween()
	tween.tween_property(music_player, "volume_db", -5.0, 1.0)
