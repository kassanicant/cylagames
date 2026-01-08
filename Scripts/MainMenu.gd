extends Control

var path_bg_music = "res://ASsets/BackgroundSound.ogg"
var path_click = "res://ASsets/ClickButton.wav"
var btn_quit

func _ready():
	# 1. PLAY MUSIC (Normal Volume)
	var music = AudioStreamPlayer.new()
	if ResourceLoader.exists(path_bg_music):
		music.stream = load(path_bg_music)
		music.volume_db = -5 # Normal volume for menu
		music.autoplay = true
		add_child(music)
	
	# 2. CONNECT PLAY BUTTON
	var btn_play = find_child("BtnPlay", true, false) # Finds button named "BtnPlay" or similar
	
	# If you didn't name it BtnPlay, try finding ANY TextureButton
	if not btn_play:
		for child in get_children():
			if child is TextureButton:
				btn_play = child
				break
	
	if btn_play:
		btn_play.pressed.connect(_on_play_pressed)
	else:
		print("❌ ERROR: Could not find a Play button in MainMenu.")

func _on_play_pressed():
	play_click_sound()
	# Small delay to hear the click before switching
	await get_tree().create_timer(0.2).timeout
	get_tree().change_scene_to_file("res://Scenes/LevelSelect.tscn")


func play_click_sound():
	var sfx = AudioStreamPlayer.new()
	sfx.stream = load(path_click)
	add_child(sfx)
	sfx.play()
	# Clean up sound node after playing
	sfx.finished.connect(sfx.queue_free)


func _on_btn_quit_pressed() -> void:
	play_click_sound()
	print("🔌 QUITTING GAME...")
	await get_tree().create_timer(0.15).timeout
	get_tree().quit() # <--- THIS CLOSES THE WINDOW
	
