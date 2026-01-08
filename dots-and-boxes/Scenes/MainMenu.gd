extends Control

# Load the cursor image
var cursor_black = load("res://ASSETS/BlackPenCursor.png")
@onready var quit_btn = $QuitBtn

func _ready():
	# 1. Setup Cursor
	# Resize if needed (optional, removes "too large" issue)
	var img = cursor_black.get_image()
	img.resize(80, 80)
	var tex = ImageTexture.create_from_image(img)
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(0, 32))
	
	# 2. FAIL-SAFE BUTTON CONNECTION
	# This line finds the button named "PlayBtn" and connects it.
	# Make sure your button in the scene tree is named "PlayBtn"!
	var btn = find_child("PlayBtn", true, false)
	if btn:
		btn.pressed.connect(_on_play_pressed)
	else:
		print("ERROR: Could not find a button named 'PlayBtn'. Please rename your button!")


	
func _on_play_pressed():
	get_tree().change_scene_to_file("res://Scenes/ModeSelection.tscn")


func _on_quit_btn_pressed() -> void:
	print("Quitting game...")
	get_tree().quit()
