class_name WorldView
extends Node2D

## WorldView visualizes the 13 Apartment 407 locations as top-down boxes and connections.
## Strictly presentation: contains zero simulation state or decision logic.

const WorldGraphClass = preload("res://scripts/world/world_graph.gd")

# 2D Screen layout for presentation only (Logical simulation does NOT use these coordinates)
const ROOM_RECTS: Dictionary = {
	# Rooftop (Top level)
	"rooftop": Rect2(590, 110, 290, 65),

	# Stairwell (Vertical circulation connecting all floors on the right)
	"stairwell": Rect2(910, 110, 140, 530),

	# Floor 2: Rooms & Corridor
	"room_201": Rect2(170, 205, 145, 80),
	"room_202": Rect2(335, 205, 145, 80),
	"room_203": Rect2(500, 205, 145, 80),
	"room_407": Rect2(665, 205, 215, 80),
	"hallway_2": Rect2(170, 305, 710, 45),

	# Floor 1: Rooms & Corridor
	"room_101": Rect2(170, 380, 215, 80),
	"room_102": Rect2(415, 380, 215, 80),
	"room_103": Rect2(660, 380, 220, 80),
	"hallway_1": Rect2(170, 480, 710, 45),

	# Ground Floor: Laundry & Lobby
	"laundry_room": Rect2(170, 555, 270, 85),
	"lobby": Rect2(470, 555, 410, 85),
}

var _world_graph: WorldGraph

func _ready() -> void:
	if _world_graph == null:
		# Fallback to default apartment graph if not injected yet
		_world_graph = WorldGraphClass.create_default_apartment()
	queue_redraw()

## Inject the WorldGraph from SimulationRunner
func setup(graph: WorldGraph) -> void:
	_world_graph = graph
	queue_redraw()

func _draw() -> void:
	var viewport_rect: Rect2 = get_viewport_rect()

	# 1. Blueprint Dark Background
	draw_rect(viewport_rect, Color(0.06, 0.08, 0.12, 1.0))

	# 2. Blueprint Grid Lines
	var grid_color: Color = Color(0.12, 0.17, 0.24, 0.4)
	var step: float = 40.0
	var x: float = 0.0
	while x < viewport_rect.size.x:
		draw_line(Vector2(x, 0), Vector2(x, viewport_rect.size.y), grid_color, 1.0)
		x += step
	var y: float = 0.0
	while y < viewport_rect.size.y:
		draw_line(Vector2(0, y), Vector2(viewport_rect.size.x, y), grid_color, 1.0)
		y += step

	# 3. Outer Building Boundary
	var building_rect: Rect2 = Rect2(150, 95, 920, 560)
	draw_rect(building_rect, Color(0.09, 0.12, 0.18, 0.9))
	draw_rect(building_rect, Color(0.25, 0.35, 0.5, 0.8), false, 2.0)

	# 4. Draw Graph Connection Lines between neighboring rooms
	var font: Font = ThemeDB.fallback_font
	var drawn_edges: Dictionary = {}
	if _world_graph != null:
		for loc_id in ROOM_RECTS.keys():
			var loc: Location = _world_graph.get_location(loc_id)
			if loc == null or not ROOM_RECTS.has(loc_id):
				continue
			var rect_a: Rect2 = ROOM_RECTS[loc_id]
			var center_a: Vector2 = rect_a.get_center()

			for neighbor_id in loc.neighbors:
				if not ROOM_RECTS.has(neighbor_id):
					continue
				var edge_key_1: String = "%s->%s" % [loc_id, neighbor_id]
				var edge_key_2: String = "%s->%s" % [neighbor_id, loc_id]
				if drawn_edges.has(edge_key_1) or drawn_edges.has(edge_key_2):
					continue
				drawn_edges[edge_key_1] = true

				var rect_b: Rect2 = ROOM_RECTS[neighbor_id]
				var center_b: Vector2 = rect_b.get_center()

				# Draw corridor connector line
				draw_line(center_a, center_b, Color(0.35, 0.55, 0.75, 0.4), 6.0)
				draw_line(center_a, center_b, Color(0.55, 0.75, 1.0, 0.7), 2.0)

	# 5. Draw Location Boxes & Information
	for loc_id in ROOM_RECTS.keys():
		var rect: Rect2 = ROOM_RECTS[loc_id]
		var loc: Location = _world_graph.get_location(loc_id) if _world_graph != null else null
		var display_title: String = loc.display_name if loc != null else loc_id

		# Determine styling based on location type
		var fill_color: Color = Color(0.14, 0.18, 0.25, 0.95)
		var border_color: Color = Color(0.3, 0.45, 0.65, 0.9)
		var title_color: Color = Color(0.9, 0.95, 1.0)
		var tag_str: String = ""

		if loc_id == "room_407":
			# Special styling for Room 407
			fill_color = Color(0.28, 0.18, 0.08, 0.95)
			border_color = Color(0.95, 0.7, 0.2, 1.0)
			title_color = Color(1.0, 0.85, 0.3)
			tag_str = "[MYSTERY / SPECIAL]"
		elif loc_id.begins_with("hallway"):
			fill_color = Color(0.12, 0.15, 0.22, 0.9)
			border_color = Color(0.35, 0.5, 0.7, 0.8)
			title_color = Color(0.8, 0.88, 0.95)
			tag_str = "[CORRIDOR]"
		elif loc_id == "stairwell":
			fill_color = Color(0.15, 0.2, 0.26, 0.95)
			border_color = Color(0.4, 0.6, 0.8, 0.9)
			title_color = Color(0.7, 0.9, 1.0)
			tag_str = "[STAIRS 1F-2F-ROOF]"
		elif loc_id == "rooftop":
			fill_color = Color(0.1, 0.16, 0.22, 0.95)
			border_color = Color(0.45, 0.65, 0.75, 0.9)
			title_color = Color(0.75, 0.95, 0.9)
			tag_str = "[OUTDOOR]"
		elif loc_id == "lobby":
			fill_color = Color(0.16, 0.22, 0.28, 0.95)
			border_color = Color(0.4, 0.6, 0.75, 0.9)
			title_color = Color(0.85, 0.95, 1.0)
			tag_str = "[ENTRANCE / LOBBY]"
		elif loc_id == "laundry_room":
			fill_color = Color(0.13, 0.18, 0.24, 0.95)
			border_color = Color(0.35, 0.55, 0.65, 0.85)
			title_color = Color(0.8, 0.9, 0.95)
			tag_str = "[UTILITY]"
		else:
			# Standard residential room
			fill_color = Color(0.13, 0.17, 0.25, 0.95)
			border_color = Color(0.3, 0.45, 0.6, 0.85)
			title_color = Color(0.88, 0.92, 0.98)
			tag_str = "[RESIDENTIAL]"

		# Draw Box
		draw_rect(rect, fill_color)
		var border_width: float = 3.0 if loc_id == "room_407" else 1.5
		draw_rect(rect, border_color, false, border_width)

		# Draw Text Titles
		var text_pos_y: float = rect.position.y + 28.0
		if loc_id == "stairwell":
			text_pos_y = rect.position.y + rect.size.y * 0.5 - 10.0

		draw_string(
			font,
			Vector2(rect.position.x + 10.0, text_pos_y),
			display_title,
			HORIZONTAL_ALIGNMENT_LEFT,
			rect.size.x - 20.0,
			14,
			title_color
		)

		if not tag_str.is_empty():
			draw_string(
				font,
				Vector2(rect.position.x + 10.0, text_pos_y + 18.0),
				tag_str,
				HORIZONTAL_ALIGNMENT_LEFT,
				rect.size.x - 20.0,
				10,
				Color(border_color.r, border_color.g, border_color.b, 0.85)
			)

	# 6. Floor Level Indicators on the left
	draw_string(font, Vector2(60, 255), "FLOOR 2", HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.5, 0.65, 0.8))
	draw_string(font, Vector2(60, 430), "FLOOR 1", HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.5, 0.65, 0.8))
	draw_string(font, Vector2(60, 605), "GROUND", HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.5, 0.65, 0.8))
