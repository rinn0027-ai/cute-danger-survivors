extends Control

var direction := Vector2.ZERO
var active := true
var touching := false
var right_side := false  # true = 右半屏捕获，false = 左半屏
var capture_full_screen := false
var fixed_position := true
var idle_visible := true

var _touch_index := -1
var _base_pos := Vector2.ZERO
var _max_radius := 72.0
var _base_panel: Panel
var _handle_panel: Panel

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base_color := Color(0.35, 0.65, 1.0, 0.18) if not right_side else Color(1.0, 0.48, 0.58, 0.18)
	var handle_color := Color(0.55, 0.8, 1.0, 0.48) if not right_side else Color(1.0, 0.7, 0.76, 0.48)
	_base_panel = _make_circle_panel(128, base_color)
	_base_panel.visible = idle_visible
	add_child(_base_panel)

	_handle_panel = _make_circle_panel(64, handle_color)
	_handle_panel.visible = idle_visible
	add_child(_handle_panel)
	_update_fixed_position()

func _make_circle_panel(diameter: int, color: Color) -> Panel:
	var p := Panel.new()
	p.size = Vector2(diameter, diameter)
	p.pivot_offset = Vector2(diameter * 0.5, diameter * 0.5)
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(diameter / 2)
	p.add_theme_stylebox_override("panel", style)
	return p

func _input(event: InputEvent) -> void:
	if not active:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	if event is InputEventScreenTouch:
		var on_correct_side: bool = capture_full_screen or (event.position.x >= vp_size.x * 0.5) == right_side
		if event.pressed and _touch_index == -1 and on_correct_side:
			_touch_index = event.index
			touching = true
			if not fixed_position:
				_base_pos = event.position
				_base_panel.position = _base_pos - Vector2(64, 64)
			_update_direction(event.position)
			_base_panel.visible = true
			_handle_panel.visible = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_update_direction(event.position)
		get_viewport().set_input_as_handled()

func set_active(value: bool) -> void:
	active = value
	if not active:
		_reset()

func _reset() -> void:
	_touch_index = -1
	touching = false
	direction = Vector2.ZERO
	_update_fixed_position()
	if _base_panel != null:
		_base_panel.visible = idle_visible and active
	if _handle_panel != null:
		_handle_panel.visible = idle_visible and active

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_fixed_position()

func _update_fixed_position() -> void:
	if _base_panel == null or _handle_panel == null or not fixed_position:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	var margin_x := clampf(vp_size.x * 0.16, 118.0, 170.0)
	var margin_y := clampf(vp_size.y * 0.15, 118.0, 156.0)
	if capture_full_screen:
		_base_pos = Vector2(vp_size.x * 0.5, vp_size.y - margin_y)
	else:
		_base_pos = Vector2(vp_size.x - margin_x, vp_size.y - margin_y) if right_side else Vector2(margin_x, vp_size.y - margin_y)
	_base_panel.position = _base_pos - Vector2(64, 64)
	_handle_panel.position = _base_pos - Vector2(32, 32)

func _update_direction(pointer_pos: Vector2) -> void:
	var delta: Vector2 = pointer_pos - _base_pos
	var clamped: Vector2 = delta.limit_length(_max_radius)
	_handle_panel.position = _base_pos + clamped - Vector2(32, 32)
	direction = clamped / _max_radius if clamped.length() > 10.0 else Vector2.ZERO
