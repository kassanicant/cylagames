extends PanelContainer
func _can_drop_data(at_position, data): return data is BottlePiece
func _drop_data(at_position, data):
	data.get_parent().remove_child(data)
	get_node("Slots").add_child(data)
