extends Control

var skill_mode: int = 0

func set_skill(mode: int) -> void:
	skill_mode = mode
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	if skill_mode == 1:
		# Fireball: glowing orange circle
		draw_arc(center, 60.0, 0.0, TAU, 64, Color(1.0, 0.6, 0.0, 0.3), 7.0)
		draw_arc(center, 60.0, 0.0, TAU, 64, Color(1.0, 0.4, 0.0, 0.8), 2.0)
	elif skill_mode == 2:
		# Arrow: precision crosshair with gap and dot
		var gap := 6.0
		var arm := 11.0
		var col := Color(1.0, 1.0, 1.0, 0.9)
		draw_line(center + Vector2(-arm - gap, 0.0), center + Vector2(-gap, 0.0), col, 1.5)
		draw_line(center + Vector2(gap, 0.0),        center + Vector2(arm + gap, 0.0), col, 1.5)
		draw_line(center + Vector2(0.0, -arm - gap), center + Vector2(0.0, -gap), col, 1.5)
		draw_line(center + Vector2(0.0, gap),        center + Vector2(0.0, arm + gap), col, 1.5)
		draw_circle(center, 2.0, col)
