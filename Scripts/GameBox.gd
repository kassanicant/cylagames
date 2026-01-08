extends Control

# --- DRAG AND DROP YOUR NODES HERE IN THE INSPECTOR ---
@export_group("Game Nodes")
@export var grid_container: GridContainer
@export var bench_slots: HBoxContainer
@export var game_over_layer: CanvasLayer # Drag your GameOverLayer here
@export var game_over_panel: Panel # Drag your GameOverPanel here

@export_group("UI Labels")
@export var score_label: Label
@export var timer_label: Label
@export var msg_label: Label # The label inside Game Over screen

@export_group("Buttons")
@export var btn_back: TextureButton
@export var btn_reset: TextureButton
@export var btn_next: TextureButton

# --- CONFIGURATION ---
var box_texture = preload("res://ASsets/CardboardBox.png")
var bottle_textures = [
	preload("res://ASsets/Bottles/Blue.png"), preload("res://ASsets/Bottles/Green.png"),
	preload("res://ASsets/Bottles/Red.png"), preload("res://ASsets/Bottles/Yellow.png"),
	preload("res://ASsets/Bottles/Purple.png"), preload("res://ASsets/Bottles/Orange.png"),
	preload("res://ASsets/Bottles/Pink.png"), preload("res://ASsets/Bottles/White.png"),
	preload("res://ASsets/Bottles/Black.png"), preload("res://ASsets/Bottles/Cyan.png"),
	preload("res://ASsets/Bottles/Lime.png"), preload("res://ASsets/Bottles/Magenta.png"),
	preload("res://ASsets/Bottles/Violet.png"), preload("res://ASsets/Bottles/Forest_Green.png")
]

var current_level = 1
var time_left = 60
var matches_needed = 0
var timer_node = Timer.new()

# --- INNER CLASSES ---
class BottlePiece extends TextureRect:
	var bottle_id = -1
	func setup(tex, id):
		texture = tex
		bottle_id = id
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		custom_minimum_size = Vector2(50, 70) 
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _get_drag_data(_at_pos):
		var preview = TextureRect.new()
		preview.texture = texture
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.size = size
		preview.modulate.a = 0.7
		set_drag_preview(preview)
		return self

class BenchScript extends HBoxContainer:
	func _can_drop_data(_at_pos, data): return data is BottlePiece
	func _drop_data(_at_pos, data):
		data.get_parent().remove_child(data)
		add_child(data)

class GameBox extends TextureRect:
	signal box_updated
	var my_correct_id = -1
	var hidden_sprite = Sprite2D.new()
	var slot = CenterContainer.new()
	var is_locked = false
	func setup(b_tex, correct_id):
		texture = b_tex
		my_correct_id = correct_id
		expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		custom_minimum_size = Vector2(80, 80)
		hidden_sprite.position = Vector2(40, 40)
		hidden_sprite.visible = false
		hidden_sprite.scale = Vector2(0.6, 0.6)
		add_child(hidden_sprite)
		slot.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(slot)
	func set_hidden_texture(tex): hidden_sprite.texture = tex
	func _can_drop_data(_at_pos, data): return not is_locked and data is BottlePiece
	func _drop_data(_at_pos, new_bottle):
		var old_parent = new_bottle.get_parent()
		if old_parent == slot: return
		if slot.get_child_count() > 0:
			var current_bottle = slot.get_child(0)
			slot.remove_child(current_bottle)
			old_parent.add_child(current_bottle)
		old_parent.remove_child(new_bottle)
		slot.add_child(new_bottle)
		box_updated.emit()
	func _notification(what):
		if what == NOTIFICATION_CHILD_ORDER_CHANGED: box_updated.emit()

# --- MAIN LOGIC ---

func _ready():
	print("--- GAME READY ---")
	
	# 1. FORCE HIDE GAME OVER UI
	if game_over_layer: game_over_layer.visible = false
	if game_over_panel: game_over_panel.visible = false

	add_child(timer_node)
	timer_node.timeout.connect(_on_timer)
	
	# 2. CONNECT BUTTONS (If they are assigned)
	if btn_back: btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://Scenes/LevelSelect.tscn"))
	if btn_reset: btn_reset.pressed.connect(start_level)
	if btn_next: btn_next.pressed.connect(next_level)
	
	if bench_slots: bench_slots.set_script(BenchScript)
	if Global.current_level: current_level = Global.current_level
	
	start_level()

func start_level():
	print("Starting Level...")
	# Force hide again to be safe
	if game_over_layer: game_over_layer.visible = false
	
	# Config
	var boxes_count = 3
	var dummies = 0
	if current_level == 2: boxes_count = 4
	if current_level == 3: boxes_count = 6
	if current_level == 4: boxes_count = 8; dummies = 2
	if current_level == 5: boxes_count = 10; dummies = 3
	if current_level == 6: boxes_count = 12; dummies = 4
	
	matches_needed = boxes_count
	time_left = 60 + (current_level * 10)
	update_ui(0)
	
	# Clear Board
	if grid_container:
		for c in grid_container.get_children(): c.queue_free()
	if bench_slots:
		for c in bench_slots.get_children(): c.queue_free()
	
	# Spawn Boxes
	var indices = range(bottle_textures.size())
	indices.shuffle()
	var level_ids = indices.slice(0, boxes_count)
	
	if grid_container:
		for id in level_ids:
			var box = GameBox.new()
			grid_container.add_child(box)
			box.setup(box_texture, id)
			box.set_hidden_texture(bottle_textures[id])
			box.box_updated.connect(check_win)
	
	# Spawn Bottles
	var bottle_ids = level_ids.duplicate()
	if dummies > 0:
		bottle_ids.append_array(indices.slice(boxes_count, boxes_count+dummies))
	bottle_ids.shuffle()
	
	if bench_slots:
		for id in bottle_ids:
			var piece = BottlePiece.new()
			bench_slots.add_child(piece)
			piece.setup(bottle_textures[id], id)
		
	timer_node.start()

func _on_timer():
	time_left -= 1
	if timer_label: timer_label.text = "Time: " + str(time_left)
	if time_left <= 0:
		game_over(false)

func check_win():
	var score = 0
	if grid_container:
		for box in grid_container.get_children():
			if box.slot.get_child_count() > 0:
				var item = box.slot.get_child(0)
				if item.bottle_id == box.my_correct_id:
					score += 1
	update_ui(score)
	if score == matches_needed:
		game_over(true)

func game_over(is_win):
	timer_node.stop()
	
	# SHOW GAME OVER UI
	if game_over_layer: game_over_layer.visible = true
	if game_over_panel: game_over_panel.visible = true
	
	if is_win:
		if msg_label: msg_label.text = "YOU WIN!"
		if btn_next: btn_next.visible = true
		if btn_reset: btn_reset.visible = true
		
		# Clean board
		if grid_container:
			for c in grid_container.get_children(): c.queue_free()
		if bench_slots:
			for c in bench_slots.get_children(): c.queue_free()
	else:
		if msg_label: msg_label.text = "GAME OVER"
		if btn_next: btn_next.visible = false
		if btn_reset: btn_reset.visible = true

func update_ui(score):
	if score_label: score_label.text = "Matches: " + str(score) + "/" + str(matches_needed)

func next_level():
	if current_level < 6:
		Global.current_level += 1
		current_level += 1
		start_level()
	else:
		get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
