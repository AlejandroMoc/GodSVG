extends Control

const ticks_interval = 4

var axis_line_color: Color
var major_grid_color: Color
var minor_grid_color: Color

var limit_left := 0.0
var limit_right := 0.0
var limit_top := 0.0
var limit_bottom := 0.0

var zoom: float
var ci := get_canvas_item()
var surface := RenderingServer.canvas_item_create()  # Used for drawing the numbers.

var unsnapped_position: Vector2


func _ready() -> void:
	Configs.grid_color_changed.connect(setup_grid_color)
	setup_grid_color()
	RenderingServer.canvas_item_set_parent(surface, ci)
	State.svg_resized.connect(queue_redraw)
	State.zoom_changed.connect(change_zoom)
	State.zoom_changed.connect(queue_redraw)
	
	State.show_grid_changed.connect(update_show_grid)
	update_show_grid()

func exit_tree() -> void:
	RenderingServer.free_rid(surface)

func change_zoom() -> void:
	zoom = State.zoom

func update_show_grid() -> void:
	visible = State.show_grid


func update() -> void:
	var new_position := unsnapped_position.snapped(Vector2(1, 1) / zoom)
	if position != new_position:
		position = unsnapped_position.snapped(Vector2(1, 1) / zoom)
		State.view_changed.emit()
	
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(zoom, zoom),
			0.0, -position * zoom)
	queue_redraw()


# Don't ask me to explain this.
func _draw() -> void:
	var grid_size := Vector2(State.viewport_size) / zoom
	RenderingServer.canvas_item_add_line(ci,
			Vector2(-position.x, 0), Vector2(-position.x, grid_size.y), axis_line_color)
	RenderingServer.canvas_item_add_line(ci,
			Vector2(0, -position.y), Vector2(grid_size.x, -position.y), axis_line_color)
	
	var major_points := PackedVector2Array()
	var minor_points := PackedVector2Array()
	var x_offset := fmod(-position.x, 1.0)
	var y_offset := fmod(-position.y, 1.0)
	var tick_distance := float(ticks_interval)
	var draw_minor_lines := zoom >= 8.0
	var mark_pixel_lines := zoom >= 128.0
	var rate := nearest_po2(roundi(maxf(64.0 / (ticks_interval * zoom), 1.0)))
	
	# The grid lines are always 1px wide, but the numbers need to be resized.
	RenderingServer.canvas_item_clear(surface)
	RenderingServer.canvas_item_set_transform(surface,
			Transform2D(0, Vector2(1, 1) / zoom, 0, Vector2.ZERO))
	
	var i := x_offset
	# Horizontal offset.
	while i <= grid_size.x:
		if fposmod(-position.x, tick_distance) != fposmod(i, tick_distance):
			if draw_minor_lines:
				minor_points.append(Vector2(i, 0))
				minor_points.append(Vector2(i, grid_size.y))
				if mark_pixel_lines:
					ThemeUtils.regular_font.draw_string(surface, Vector2(i * zoom + 4, 14),
							String.num_int64(floori(i + position.x)),
							HORIZONTAL_ALIGNMENT_LEFT, -1, 14, axis_line_color)
		else:
			var coord := snappedi(i + position.x, ticks_interval)
			if int(float(coord) / ticks_interval) % rate == 0:
				major_points.append(Vector2(i, 0))
				major_points.append(Vector2(i, grid_size.y))
				ThemeUtils.regular_font.draw_string(surface, Vector2(i * zoom + 4, 14),
						String.num_int64(coord), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
						axis_line_color)
			elif coord % rate == 0:
				minor_points.append(Vector2(i, 0))
				minor_points.append(Vector2(i, grid_size.y))
		i += 1.0
	i = y_offset
	# Vertical offset.
	while i < grid_size.y:
		if fposmod(-position.y, tick_distance) != fposmod(i, tick_distance):
			if draw_minor_lines:
				minor_points.append(Vector2(0, i))
				minor_points.append(Vector2(grid_size.x, i))
				if mark_pixel_lines:
					ThemeUtils.regular_font.draw_string(surface, Vector2(4, i * zoom + 14),
							String.num_int64(floori(i + position.y)),
							HORIZONTAL_ALIGNMENT_LEFT, -1, 14, axis_line_color)
		else:
			var coord := snappedi(i + position.y, ticks_interval)
			if int(coord / float(ticks_interval)) % rate == 0:
				major_points.append(Vector2(0, i))
				major_points.append(Vector2(grid_size.x, i))
				ThemeUtils.regular_font.draw_string(surface, Vector2(4, i * zoom + 14),
						String.num_int64(coord), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
						axis_line_color)
			elif coord % rate == 0:
				minor_points.append(Vector2(0, i))
				minor_points.append(Vector2(grid_size.x, i))
		i += 1.0
	if not major_points.is_empty():
		draw_multiline(major_points, major_grid_color)
	if not minor_points.is_empty():
		draw_multiline(minor_points, minor_grid_color)


func setup_grid_color() -> void:
	axis_line_color = Color(Configs.savedata.grid_color, 0.75)
	major_grid_color = Color(Configs.savedata.grid_color, 0.35)
	minor_grid_color = Color(Configs.savedata.grid_color, 0.15)
	queue_redraw()
