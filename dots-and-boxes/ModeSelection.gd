extends Control

func _ready():
	# Connect the Play buttons
	$BtnFriend.pressed.connect(_on_friend_pressed)
	$BtnBot.pressed.connect(_on_bot_pressed)
	
	# FIX: Connect the Back Button! (Assuming it is named 'BackBtn')
	var back = find_child("BackBtn") # Use find_child to be safe
	if back:
		back.pressed.connect(_on_back_btn_pressed)

func _on_friend_pressed():
	Global.is_vs_bot = false
	start_game()

func _on_bot_pressed():
	Global.is_vs_bot = true
	start_game()

func _on_back_btn_pressed():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
	
func start_game():
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")
