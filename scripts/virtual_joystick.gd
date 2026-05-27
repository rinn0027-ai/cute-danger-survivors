extends Control

var direction := Vector2.ZERO
var active := true
var touching := false

var _touch_index := -1
var _base_pos := Vector2.ZERO
var _max_radius := 72.0
var _base_panel: Panel
var _handle_panel: Panel

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_base_panel = _make_circle_panel(128, Color(1, 1, 1, 0.15))
	_base_panel.visible = false
	add_child(_base_panel)

	_handle_panel = _make_circle_panel(64, Color(1, 1, 1, 0.38))
	_handle_panel.visible = false
	add_child(_handle_panel)

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
		_reset()
		return
	var vp_size: Vector2 = get_viewport_rect().size
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1 and event.position.x < vp_size.x * 0.5:
			_touch_index = event.index
			touching = true
			_base_pos = event.position
			_base_panel.position = _base_pos - Vector2(64, 64)
			_handle_panel.position = _base_pos - Vector2(32, 32)
			_base_panel.visible = true
			_handle_panel.visible = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch_index:
			_reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		var delta: Vector2 = event.position - _base_pos
		var clamped: Vector2 = delta.limit_length(_max_radius)
		_handle_panel.position = _base_pos + clamped - Vector2(32, 32)
		direction = clamped / _max_radius if clamped.length() > 10.0 else Vector2.ZERO
		get_viewport().set_input_as_handled()

func set_active(value: bool) -> void:
	active = value
	if not active:
		_reset()

func _reset() -> void:
	_touch_index = -1
	touching = false
	direction = Vector2.ZERO
	if _base_panel != null:
		_base_panel.visible = false
	if _handle_panel != null:
		_handle_panel.visible = false
