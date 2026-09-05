class_name WorldView
extends Node2D

## WorldView presentation layer for Apartment 407.
## Strictly visualization: contains no simulation state or logic.

@export var background_color: Color = Color(0.08, 0.1, 0.14, 1.0)
@export var grid_color: Color = Color(0.15, 0.2, 0.28, 0.5)
@export var border_color: Color = Color(0.25, 0.4, 0.55, 0.8)

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()
	# Draw background
	draw_rect(viewport_rect, background_color)

	# Draw subtle blueprint grid lines
	var step: float = 64.0
	var x: float = 0.0
	while x < viewport_rect.size.x:
		draw_line(Vector2(x, 0), Vector2(x, viewport_rect.size.y), grid_color, 1.0)
		x += step

	var y: float = 0.0
	while y < viewport_rect.size.y:
		draw_line(Vector2(0, y), Vector2(viewport_rect.size.x, y), grid_color, 1.0)
		y += step

	# Draw central placeholder frame for apartment blueprint
	var center: Vector2 = viewport_rect.size * 0.5
	var frame_rect: Rect2 = Rect2(center - Vector2(360, 200), Vector2(720, 400))
	draw_rect(frame_rect, Color(0.12, 0.16, 0.22, 0.8))
	draw_rect(frame_rect, border_color, false, 2.0)

