extends Control

const MusicPlayer := preload("res://scripts/music_player.gd")
const UI_FONT_PATH := "res://assets/fonts/GameFont.otf"

func _ready() -> void:
	add_child(MusicPlayer.new())
	theme = _make_ui_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color("#0d1117")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := VBoxContainer.new()
	center.anchor_left = 0.06
	center.anchor_right = 0.94
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = 0
	center.offset_right = 0
	center.offset_top = -220
	center.offset_bottom = 220
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 18)
	add_child(center)

	var title := Label.new()
	title.text = "Cute Danger Survivors"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#ffd464"))
	title.add_theme_color_override("font_outline_color", Color("#10131f"))
	title.add_theme_constant_override("outline_size", 4)
	center.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "roguelike · bullet hell · survive!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.modulate = Color("#8899aa")
	center.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	center.add_child(spacer)

	var controls := Label.new()
	controls.text = "Mobile  Stick = Move · Auto aim & fire\nDesktop  WASD / Arrows = Move · Mouse = Aim · Auto fire\nDefeat enemies · Level up · Choose upgrades · Beat the Boss"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_theme_font_size_override("font_size", 15)
	controls.modulate = Color("#99aabb")
	center.add_child(controls)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	center.add_child(spacer2)

	var start_btn := Button.new()
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size = Vector2(240, 64)
	start_btn.add_theme_font_size_override("font_size", 26)
	start_btn.pressed.connect(_start_game)
	center.add_child(start_btn)

	var hint := Label.new()
	hint.text = "or press Enter / Space"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color("#667788")
	center.add_child(hint)

func _start_game() -> void:
	_request_mobile_fullscreen()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_start_game()

func _request_mobile_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(() => {
			const root = document.documentElement;
			if (root.requestFullscreen && !document.fullscreenElement) {
				root.requestFullscreen().catch(() => {});
			}
			if (screen.orientation && screen.orientation.lock) {
				screen.orientation.lock('portrait').catch(() => {});
			}
			document.body.style.overflow = 'hidden';
			document.documentElement.style.overflow = 'hidden';
		})();
	""")

func _make_ui_theme() -> Theme:
	var ui_theme := Theme.new()
	var ui_font := load(UI_FONT_PATH) as Font
	if ui_font != null:
		ui_theme.default_font = ui_font
	ui_theme.default_font_size = 16
	return ui_theme
