extends TextureRect

var bottle_id = -1

func setup(tex, id):
	texture = tex
	bottle_id = id

func _get_drag_data(at_position):
	var preview = TextureRect.new()
	preview.texture = texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = size
	preview.modulate.a = 0.5
	set_drag_preview(preview)
	return self
