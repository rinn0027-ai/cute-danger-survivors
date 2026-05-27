extends Control

const MusicPlayer := preload("res://scripts/music_player.gd")

func _ready() -> void:
	add_child(MusicPlayer.new())
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color("#0d1117")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := VBoxContainer.new()
	center.anchor_left = 0.5
	center.anchor_right = 0.5
	center.anchor_top = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -320
	center.offset_right = 320
	center.offset_top = -220
	center.offset_bottom = 220
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 22)
	add_child(center)

	var title := Label.new()
	title.text = "Cute Danger Survivors"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
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
	controls.text = "📱 Mobile  Left stick = Move · Right stick = Aim & Fire\n⌨️  Desktop  WASD / Arrows = Move · Mouse = Aim · Auto fire\nDefeat enemies · Level up · Choose upgrades · Beat the Boss"
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_theme_font_size_override("font_size", 18)
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
				screen.orientation.lock('landscape').catch(() => {});
			}
			document.body.style.overflow = 'hidden';
			document.documentElement.style.overflow = 'hidden';
		})();
	""")
