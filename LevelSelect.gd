extends Control

var path_bg_music = "res://ASsets/BackgroundSound.ogg"
var path_click = "res://ASsets/ClickButton.wav"

func _ready():
	# 1. PLAY MUSIC
	var music = AudioStreamPlayer.new()
	if ResourceLoader.exists(path_bg_music):
		music.stream = load(path_bg_music)
		music.volume_db = -5
		music.autoplay = true
		add_child(music)

	# 2. CONNECT BUTTONS
	# Back Button
	var btn_back = find_child("BtnBack", true, false)
	if btn_back:
		btn_back.pressed.connect(func(): 
			play_click_sound()
			await get_tree().create_timer(0.1).timeout
			get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
		)

	# Level Buttons (Assuming they are in a GridContainer)
	var grid = find_child("GridContainer", true, false)
	if grid:
		var level_num = 1
		for child in grid.get_children():
			if child is TextureButton:
				# Connect each button to the level loader
				child.pressed.connect(_on_level_pressed.bind(level_num))
				level_num += 1

func _on_level_pressed(lvl):
	play_click_sound()
	Global.current_level = lvl
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")

func play_click_sound():
	var sfx = AudioStreamPlayer.new()
	sfx.stream = load(path_click)
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
