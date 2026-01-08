extends Control

# --- SETTINGS ---
var grid_width = 5
var grid_height = 6
var cell_size = 70
var board_margin = 35
var dot_radius = 12
var line_thickness = 10
var turn_time_limit = 30 
var cursor_hotspot = Vector2(0, 80)

# --- COLORS ---
var color_p1 = Color.DODGER_BLUE
var color_p2 = Color.CRIMSON
var color_dots = Color.BLACK 
var color_neutral_line = Color(0, 0, 0, 0.1)
var color_line_hover = Color(0, 0, 0, 0.3)
var color_line_taken = Color.BLACK
var color_bg_box_alpha = 0.5 

# --- STATE ---
var current_player = 0
var lines_state = {} 
var dot_data = {}    
var box_owners = {}
var scores = [0, 0]
var game_over = false
var hovered_line = null
var last_timer_int = -1

# --- NODES ---
@onready var background = $"../Background"
@onready var turn_timer = $"../TurnTimer"
@onready var timer_label = $"../TimerLabel"
@onready var score_p1_label = $"../ScoreP1"
@onready var score_p2_label = $"../ScoreP2"
@onready var back_btn = $"../BackBtn"

# AUDIO NODES (Local SFX only, Music is now global)
@onready var sfx_player = $"../SfxPlayer"       
@onready var countdown_sfx = $"../CountdownSfx"

# GAME OVER NODES
@onready var game_over_layer = $"../GameOverLayer"
@onready var game_over_panel = $"../GameOverLayer/GameOverPanel"
@onready var title_label = $"../GameOverLayer/GameOverPanel/TitleLabel"
@onready var retry_btn = $"../GameOverLayer/GameOverPanel/RetryBtn"
@onready var menu_btn = $"../GameOverLayer/GameOverPanel/MenuBtn"

# RESOURCES
var cursor_blue_tex
var cursor_red_tex
var bot_cursor_sprite : Sprite2D 
var bg_blue_tex
var bg_red_tex

# AUDIO ASSETS (For local game logic)
var audio_click_line

func _ready():
	print("GAME STARTED")
	
	# 1. MANAGE GLOBAL AUDIO
	# Lower music volume for concentration during gameplay
	if AudioManager:
		AudioManager.set_volume_low()
	
	# Load local click sound for line drawing
	if ResourceLoader.exists("res://ASSETS/Click(PenSound).wav"):
		audio_click_line = load("res://ASSETS/Click(PenSound).wav")
	if sfx_player and audio_click_line:
		sfx_player.stream = audio_click_line

	# 2. HIDE GAME OVER SCREEN
	if game_over_layer: game_over_layer.visible = false
	
	# 3. CONNECT BUTTONS (Using Global Click Sound)
	if retry_btn: 
		retry_btn.pressed.connect(_on_retry_pressed)
		retry_btn.pressed.connect(AudioManager.play_click)
	if menu_btn: 
		menu_btn.pressed.connect(_on_menu_pressed)
		menu_btn.pressed.connect(AudioManager.play_click)

	# 4. LOAD VISUAL ASSETS
	bg_blue_tex = load("res://ASSETS/BlueBackground.png") 
	bg_red_tex = load("res://ASSETS/RedBackground.png")
	var img_b = load("res://ASSETS/BluePenCursor.png").get_image()
	var img_r = load("res://ASSETS/RedPenCursor.png").get_image()
	img_b.resize(80, 80)
	img_r.resize(80, 80)
	cursor_blue_tex = ImageTexture.create_from_image(img_b)
	cursor_red_tex = ImageTexture.create_from_image(img_r)

	# 5. SETUP BOARD
	bot_cursor_sprite = Sprite2D.new()
	bot_cursor_sprite.texture = cursor_red_tex
	bot_cursor_sprite.visible = false
	bot_cursor_sprite.z_index = 50 
	bot_cursor_sprite.offset = Vector2(0, 40)
	add_child(bot_cursor_sprite)

	if back_btn:
		back_btn.z_index = 50
		if not back_btn.pressed.is_connected(_on_back_pressed):
			back_btn.pressed.connect(_on_back_pressed)
			back_btn.pressed.connect(AudioManager.play_click)

	var board_w = (grid_width * cell_size) + (board_margin * 2)
	var board_h = (grid_height * cell_size) + (board_margin * 2)
	size = Vector2(board_w, board_h)
	var screen_size = get_viewport_rect().size
	position = (screen_size - size) / 2
	position.y += 30 
	
	if turn_timer: turn_timer.timeout.connect(_on_timer_timeout)
	
	# 6. INIT DATA
	for x in range(grid_width + 1):
		for y in range(grid_height + 1):
			dot_data[Vector2(x,y)] = {0: 0, 1: 0} 

	mouse_filter = Control.MOUSE_FILTER_STOP
	start_turn()
	queue_redraw()

func _exit_tree():
	# Reset volume if scene is unloaded unexpectedly
	# Note: This runs when scene changes, ensuring menu volume is restored
	pass 

func _process(delta):
	if Global.is_vs_bot:
		timer_label.text = "VS BOT" if !game_over else ""
		timer_label.modulate = Color.DARK_GREEN
		return

	if not game_over and turn_timer and !turn_timer.is_stopped():
		var time_left = int(turn_timer.time_left)
		timer_label.text = str(time_left)
		if time_left != last_timer_int:
			last_timer_int = time_left
			if time_left <= 5 and time_left > 0:
				if countdown_sfx: countdown_sfx.play()
				timer_label.modulate = Color.RED
			elif time_left <= 0:
				if countdown_sfx: countdown_sfx.stop()

# --- INPUT ---
func _gui_input(event):
	if game_over: return
	if Global.is_vs_bot and current_player == 1: return

	if event is InputEventMouseMotion:
		var prev = hovered_line
		hovered_line = find_nearest_line_slot(event.position)
		if prev != hovered_line: queue_redraw()

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var target = find_nearest_line_slot(event.position)
			if target != null: try_place_line(target[0], target[1])

func find_nearest_line_slot(local_mouse):
	var pos = local_mouse - Vector2(board_margin, board_margin)
	var gx = pos.x / cell_size
	var gy = pos.y / cell_size
	
	var dist_x = abs(gx - round(gx)) 
	var dist_y = abs(gy - round(gy)) 
	
	if dist_x > 0.35 and dist_y > 0.35: return null
	
	if dist_x < dist_y:
		var x = round(gx)
		var y_start = floor(gy)
		if x < 0 or x > grid_width: return null
		if y_start < 0 or y_start >= grid_height: return null
		return [Vector2(x, y_start), Vector2(x, y_start + 1)]
	else:
		var y = round(gy)
		var x_start = floor(gx)
		if y < 0 or y > grid_height: return null
		if x_start < 0 or x_start >= grid_width: return null
		return [Vector2(x_start, y), Vector2(x_start + 1, y)]

func try_place_line(start, end):
	var key = str(start) + "|" + str(end)
	if lines_state.has(key): return 
	
	if countdown_sfx: countdown_sfx.stop()
	if turn_timer: turn_timer.stop()
	
	# PLAY GAMEPLAY SOUND (Drawing line)
	if sfx_player: 
		sfx_player.pitch_scale = randf_range(0.9, 1.1)
		sfx_player.play()
	
	lines_state[key] = current_player
	hovered_line = null
	
	if check_boxes():
		scores[current_player] += 1
		check_win_condition()
		if not game_over: 
			if Global.is_vs_bot and current_player == 1:
				start_bot_thinking()
			else:
				start_turn()
	else:
		current_player = 1 - current_player
		start_turn()
	
	queue_redraw()

# --- DRAWING ---
func _draw():
	var offset = Vector2(board_margin, board_margin)
	
	for coord in box_owners:
		var color = color_p1 if box_owners[coord] == 0 else color_p2
		color.a = color_bg_box_alpha
		var pos = (coord * cell_size) + offset
		draw_rect(Rect2(pos, Vector2(cell_size, cell_size)), color, true)

	for y in range(grid_height + 1):
		for x in range(grid_width):
			draw_line_custom(Vector2(x, y), Vector2(x+1, y), color_neutral_line, offset)
	for x in range(grid_width + 1):
		for y in range(grid_height):
			draw_line_custom(Vector2(x, y), Vector2(x, y+1), color_neutral_line, offset)

	if hovered_line != null and (!Global.is_vs_bot or current_player == 0):
		var key = str(hovered_line[0]) + "|" + str(hovered_line[1])
		if !lines_state.has(key):
			draw_line_custom(hovered_line[0], hovered_line[1], color_line_hover, offset)

	for key in lines_state:
		var parts = key.split("|")
		var p1 = str_to_var("Vector2" + parts[0])
		var p2 = str_to_var("Vector2" + parts[1])
		draw_line_custom(p1, p2, color_line_taken, offset)

	for x in range(grid_width + 1):
		for y in range(grid_height + 1):
			var pos = (Vector2(x, y) * cell_size) + offset
			draw_circle(pos, dot_radius, color_dots)

func draw_line_custom(grid_start, grid_end, color, offset):
	var p1 = (grid_start * cell_size) + offset
	var p2 = (grid_end * cell_size) + offset
	draw_line(p1, p2, color, line_thickness)

func check_boxes():
	var made_box = false
	for x in range(grid_width):
		for y in range(grid_height):
			var c = Vector2(x, y)
			if box_owners.has(c): continue
			
			var top = lines_state.has(str(c) + "|" + str(Vector2(x+1, y)))
			var bot = lines_state.has(str(Vector2(x, y+1)) + "|" + str(Vector2(x+1, y+1)))
			var left = lines_state.has(str(c) + "|" + str(Vector2(x, y+1)))
			var right = lines_state.has(str(Vector2(x+1, y)) + "|" + str(Vector2(x+1, y+1)))
			
			if top and bot and left and right:
				box_owners[c] = current_player
				made_box = true
	return made_box

func start_turn():
	if game_over: return
	update_ui()
	if Global.is_vs_bot:
		turn_timer.stop() 
		if current_player == 1: start_bot_thinking()
	else:
		turn_timer.start(turn_time_limit)
		last_timer_int = -1

# --- BOT & WIN LOGIC ---
func start_bot_thinking():
	bot_cursor_sprite.visible = true
	var target_move = get_smart_move()
	if target_move == null: return
	
	var grid_center = (target_move[0] + target_move[1]) / 2.0
	var pixel_target = (grid_center * cell_size) + Vector2(board_margin, board_margin)
	
	var tween = create_tween()
	var fake_pos = pixel_target + Vector2(randf_range(-100, 100), randf_range(-100, 100))
	tween.tween_property(bot_cursor_sprite, "position", fake_pos, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(bot_cursor_sprite, "position", pixel_target, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): try_place_line(target_move[0], target_move[1]))

func get_smart_move():
	var available = []
	for x in range(grid_width):
		for y in range(grid_height + 1):
			if !lines_state.has(str(Vector2(x,y)) + "|" + str(Vector2(x+1,y))):
				available.append([Vector2(x,y), Vector2(x+1,y), "h"])
	for x in range(grid_width + 1):
		for y in range(grid_height):
			if !lines_state.has(str(Vector2(x,y)) + "|" + str(Vector2(x,y+1))):
				available.append([Vector2(x,y), Vector2(x,y+1), "v"])
	
	var scoring = []
	var safe = []
	var bad = [] 
	
	for m in available:
		var p1 = m[0]; var type = m[2]
		var boxes = []
		if type == "h":
			if p1.y > 0: boxes.append(Vector2(p1.x, p1.y - 1))
			if p1.y < grid_height: boxes.append(Vector2(p1.x, p1.y))
		else: 
			if p1.x > 0: boxes.append(Vector2(p1.x - 1, p1.y))
			if p1.x < grid_width: boxes.append(Vector2(p1.x, p1.y))
			
		var closes = false
		var gives = false
		for b in boxes:
			var c = count_lines(b)
			if c == 3: closes = true
			if c == 2: gives = true
		
		if closes: scoring.append(m)
		elif gives: bad.append(m)
		else: safe.append(m)
		
	if scoring.size() > 0: return scoring.pick_random()
	if safe.size() > 0: return safe.pick_random()
	if bad.size() > 0: return bad.pick_random()
	return null

func count_lines(b):
	var c = 0
	if lines_state.has(str(Vector2(b.x, b.y)) + "|" + str(Vector2(b.x+1, b.y))): c+=1
	if lines_state.has(str(Vector2(b.x, b.y+1)) + "|" + str(Vector2(b.x+1, b.y+1))): c+=1
	if lines_state.has(str(Vector2(b.x, b.y)) + "|" + str(Vector2(b.x, b.y+1))): c+=1
	if lines_state.has(str(Vector2(b.x+1, b.y)) + "|" + str(Vector2(b.x+1, b.y+1))): c+=1
	return c

func update_ui():
	score_p1_label.text = str(scores[0])
	score_p2_label.text = str(scores[1])
	score_p1_label.modulate = color_p1
	score_p2_label.modulate = color_p2
	
	if background:
		if current_player == 0 and bg_blue_tex: background.texture = bg_blue_tex
		elif current_player == 1 and bg_red_tex: background.texture = bg_red_tex
	
	# CURSOR LOGIC
	if Global.is_vs_bot and current_player == 1:
		Input.set_custom_mouse_cursor(null) 
	else:
		if bot_cursor_sprite: bot_cursor_sprite.visible = false 
		if current_player == 0:
			Input.set_custom_mouse_cursor(cursor_blue_tex, Input.CURSOR_ARROW, cursor_hotspot)
		else:
			Input.set_custom_mouse_cursor(cursor_red_tex, Input.CURSOR_ARROW, cursor_hotspot)

func check_win_condition():
	if box_owners.size() == grid_width * grid_height:
		game_over = true
		if turn_timer: turn_timer.stop()
		
		Input.set_custom_mouse_cursor(null) # Show default cursor for UI
		
		# SHOW GAME OVER UI
		game_over_layer.visible = true
		
		if Global.is_vs_bot:
			if scores[0] > scores[1]:
				title_label.text = "YOU WON!"
				title_label.modulate = Color.DARK_BLUE
			else:
				title_label.text = "GAME OVER"
				title_label.modulate = Color.INDIAN_RED
		else:
			if scores[0] > scores[1]:
				title_label.text = "BLUE WINS!"
				title_label.modulate = Color.NAVY_BLUE
			elif scores[1] > scores[0]:
				title_label.text = "RED WINS!"
				title_label.modulate = Color.DARK_RED
			else:
				title_label.text = "DRAW!"
				title_label.modulate = Color.WHITE

func _on_timer_timeout():
	current_player = 1 - current_player
	start_turn()

func _on_back_pressed():
	# Restore volume when leaving game
	if AudioManager: AudioManager.set_volume_normal()
	get_tree().change_scene_to_file("res://Scenes/ModeSelection.tscn")

func _on_retry_pressed():
	# Restarting game keeps low volume (handled in ready)
	get_tree().reload_current_scene()

func _on_menu_pressed():
	# Restore volume when going to menu
	if AudioManager: AudioManager.set_volume_normal()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
