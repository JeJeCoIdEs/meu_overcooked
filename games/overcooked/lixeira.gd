extends StaticBody2D
class_name Lixeira

func discard_item(item: Item) -> void:
	if item:
		item.queue_free()
		var sfx = SoundEffects.get_instance()
		if sfx:
			sfx.play("trash")
		var tween = create_tween()
		scale = Vector2(0.85, 1.25)
		tween.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
