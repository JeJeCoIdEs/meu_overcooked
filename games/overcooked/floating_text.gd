extends Node2D
class_name FloatingText

@onready var label: Label = $Label

func setup(text: String, color: Color = Color.WHITE, duration: float = 1.0) -> void:
	if not label:
		label = get_node_or_null("Label")
	if label:
		label.text = text
		label.add_theme_color_override("font_color", color)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		label.add_theme_font_size_override("font_size", 12)
	
	scale = Vector2(0.5, 0.5)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.15)
	tween.tween_property(self, "position:y", position.y - 35.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, duration * 0.35).set_delay(duration * 0.65)
	tween.chain().tween_callback(queue_free)
