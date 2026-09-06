class_name WorldView
extends Node2D

## WorldView visualizes the 13 Apartment 407 locations as top-down boxes, connections,
## and characters as simple colored circles with names.
## Strictly presentation: contains zero simulation state or decision logic.

const WorldGraphClass = preload("res://scripts/world/world_graph.gd")
const CharacterStateClass = preload("res://scripts/characters/character_state.gd")

## Emitted when the player clicks a character circle. TASK-014 Observer UI.
signal character_selected(char_id: String)

const CHARACTER_CLICK_RADIUS: float = 16.0

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
var _characters: Array[CharacterState] = []

## Screen-space hit regions rebuilt every draw so clicks can be resolved
## back to a character ID without duplicating layout logic.
var _character_hit_positions: Dictionary = {}

func _ready() -> void:
	if _world_graph == null:
		# Fallback to default apartment graph if not injected yet
		_world_graph = WorldGraphClass.create_default_apartment()
	queue_redraw()

## Resolve a click at the given local position to a character ID, if any
## circle is within CHARACTER_CLICK_RADIUS of it.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_id: String = _resolve_click(event.position)
		if not clicked_id.is_empty():
			character_selected.emit(clicked_id)

func _resolve_click(pos: Vector2) -> String:
	var closest_id: String = ""
	var closest_dist: float = CHARACTER_CLICK_RADIUS
	for char_id in _character_hit_positions.keys():
		var dist: float = pos.distance_to(_character_hit_positions[char_id])
		if dist <= closest_dist:
			closest_dist = dist
			closest_id = char_id
	return closest_id

## Inject the WorldGraph and optional characters from SimulationRunner
func setup(graph: WorldGraph, characters: Array[CharacterState] = []) -> void:
	_world_graph = graph
	_characters = characters
	queue_redraw()

## Update characters rendered in the world view
func set_characters(characters: Array[CharacterState]) -> void:
	_characters = characters
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
			fill_color = Color(0.13, 0.17, 0.25, 0.95)
			border_color = Color(0.3, 0.45, 0.6, 0.85)
			title_color = Color(0.88, 0.92, 0.98)
			tag_str = "[RESIDENTIAL]"

		# Draw Box
		draw_rect(rect, fill_color)
		var border_width: float = 3.0 if loc_id == "room_407" else 1.5
		draw_rect(rect, border_color, false, border_width)

		# Draw Text Titles (with font null guard)
		if font != null:
			var text_pos_y: float = rect.position.y + 24.0
			if loc_id == "stairwell":
				text_pos_y = rect.position.y + 28.0

			draw_string(
				font,
				Vector2(rect.position.x + 10.0, text_pos_y),
				display_title,
				HORIZONTAL_ALIGNMENT_LEFT,
				rect.size.x - 20.0,
				13,
				title_color
			)

			if not tag_str.is_empty():
				draw_string(
					font,
					Vector2(rect.position.x + 10.0, text_pos_y + 15.0),
					tag_str,
					HORIZONTAL_ALIGNMENT_LEFT,
					rect.size.x - 20.0,
					10,
					Color(border_color.r, border_color.g, border_color.b, 0.85)
				)

	# 6. Draw Characters as simple circles with names inside their rooms
	_draw_characters(font)

	# 7. Floor Level Indicators on the left (with font null guard)
	if font != null:
		draw_string(font, Vector2(60, 255), "FLOOR 2", HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.5, 0.65, 0.8))
		draw_string(font, Vector2(60, 430), "FLOOR 1", HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.5, 0.65, 0.8))
		draw_string(font, Vector2(60, 605), "GROUND", HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.5, 0.65, 0.8))

func _draw_characters(font: Font) -> void:
	_character_hit_positions.clear()

	# Group characters by location
	var by_location: Dictionary = {}
	for c in _characters:
		var loc_id: String = c.current_location
		if not by_location.has(loc_id):
			by_location[loc_id] = []
		by_location[loc_id].append(c)

	for loc_id in by_location.keys():
		if not ROOM_RECTS.has(loc_id):
			continue
		var rect: Rect2 = ROOM_RECTS[loc_id]
		var chars_in_room: Array = by_location[loc_id]

		var circle_radius: float = 10.0
		var start_x: float = rect.position.x + 24.0
		var base_y: float = rect.position.y + rect.size.y - 20.0

		# For narrow corridors, adjust position
		if loc_id.begins_with("hallway"):
			base_y = rect.position.y + 24.0

		for idx in range(chars_in_room.size()):
			var c: CharacterState = chars_in_room[idx] as CharacterState
			var circle_pos: Vector2 = Vector2(start_x + idx * 56.0, base_y)

			# Color coding for characters
			var body_color: Color
			var outline_color: Color

			if c.is_protagonist:
				body_color = Color(0.2, 0.85, 1.0, 1.0) # Bright cyan for protagonist
				outline_color = Color(1.0, 0.9, 0.3, 1.0) # Gold ring
			else:
				# Deterministic pleasant colors for NPCs
				var hue: float = fmod(abs(c.name.hash()) * 0.13, 1.0)
				body_color = Color.from_hsv(hue, 0.55, 0.9)
				outline_color = Color(0.1, 0.15, 0.25, 1.0)

			# Draw character circle
			draw_circle(circle_pos, circle_radius, body_color)
			draw_arc(circle_pos, circle_radius, 0.0, TAU, 24, outline_color, 2.0 if c.is_protagonist else 1.2)

			# Draw protagonist indicator badge
			if c.is_protagonist:
				draw_circle(circle_pos, 3.0, Color.WHITE)

			_character_hit_positions[c.id] = circle_pos

			# Draw character name and current action
			if font != null:
				var label_text: String = "%s (P)" % c.name if c.is_protagonist else c.name
				var label_pos: Vector2 = Vector2(circle_pos.x - 24.0, circle_pos.y - 12.0)
				draw_string(
					font,
					label_pos,
					label_text,
					HORIZONTAL_ALIGNMENT_CENTER,
					48.0,
					10,
					Color(0.95, 0.98, 1.0, 0.95)
				)

				var action_label: String = str(c.current_action.get("id", "idle")).capitalize()
				draw_string(
					font,
					Vector2(circle_pos.x - 24.0, circle_pos.y + 20.0),
					action_label,
					HORIZONTAL_ALIGNMENT_CENTER,
					48.0,
					8,
					Color(0.65, 0.85, 0.95, 0.85)
				)
