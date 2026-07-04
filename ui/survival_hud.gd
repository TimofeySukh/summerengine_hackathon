extends Control

const FONT_BOLD := preload("res://demo_page/fonts/Montserrat-Bold.ttf")
const FONT_MEDIUM := preload("res://demo_page/fonts/Montserrat-Medium.ttf")

@onready var _wave_value: Label = %WaveValue
@onready var _kills_value: Label = %KillsValue
@onready var _time_value: Label = %TimeValue
@onready var _best_value: Label = %BestValue
@onready var _banner: Control = %IntermissionBanner
@onready var _banner_title: Label = %BannerTitle
@onready var _banner_subtitle: Label = %BannerSubtitle
@onready var _wave_remaining: Label = %WaveRemaining

var _director: Node = null
var _last_banner_message := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_ignore_mouse_recursive(self)
	_style_panels()
	_banner.modulate.a = 0.0
	_banner.visible = false
	call_deferred("_bind_director")


func _bind_director() -> void:
	_director = get_tree().get_first_node_in_group("run_director")
	if _director == null:
		return
	if not _director.stats_updated.is_connected(_on_stats_updated):
		_director.stats_updated.connect(_on_stats_updated)
	_on_stats_updated(_director.get_snapshot())


func _on_stats_updated(snapshot: Dictionary) -> void:
	_wave_value.text = str(snapshot.get("wave", 0))
	_kills_value.text = str(snapshot.get("kills", 0))
	_time_value.text = _format_time(float(snapshot.get("time", 0.0)))

	var best_wave: int = snapshot.get("best_wave", 0)
	var best_kills: int = snapshot.get("best_kills", 0)
	if best_wave > 0:
		_best_value.text = "Best  W%d  ·  %d kills" % [best_wave, best_kills]
	else:
		_best_value.text = "Best  —"

	var phase: int = int(snapshot.get("phase", 0))
	var remaining: int = int(snapshot.get("enemies_remaining", 0))
	if phase == 1:
		_wave_remaining.text = "%d spawning" % remaining if remaining > 0 else "clear the wave"
	else:
		_wave_remaining.text = ""

	var message := str(snapshot.get("intermission_message", ""))
	if message.is_empty():
		_last_banner_message = ""
		_hide_banner()
	elif message != _last_banner_message:
		_last_banner_message = message
		_show_banner(message, phase)
	elif not _banner.visible:
		_show_banner(message, phase)


func _show_banner(message: String, phase: int) -> void:
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = true
	_banner_title.text = message
	if phase == 0 and message == "SURVIVE THE WAVES":
		_banner_subtitle.text = "Hold the neon arena."
	elif message.ends_with("INCOMING"):
		_banner_subtitle.text = "Brace yourself."
	elif message.ends_with("CLEAR"):
		_banner_subtitle.text = "Catch your breath."
	else:
		_banner_subtitle.text = ""

	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_banner() -> void:
	if not _banner.visible:
		return

	var tween := create_tween()
	tween.tween_property(_banner, "modulate:a", 0.0, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_banner.visible = false
	)


func _format_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	var minutes := total / 60
	var secs := total % 60
	return "%d:%02d" % [minutes, secs]


func _style_panels() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.06, 0.1, 0.72)
	panel_style.border_color = Color(0.18, 0.28, 0.52, 0.85)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 14.0
	panel_style.content_margin_top = 10.0
	panel_style.content_margin_right = 14.0
	panel_style.content_margin_bottom = 10.0

	for panel_name in ["WavePanel", "KillsPanel", "TimePanel"]:
		var panel := get_node_or_null("TopBar/" + panel_name if panel_name != "WavePanel" else "TopBar/WavePanel")
		if panel_name == "KillsPanel":
			panel = get_node_or_null("TopBar/StatsPanel/KillsPanel")
		elif panel_name == "TimePanel":
			panel = get_node_or_null("TopBar/StatsPanel/TimePanel")
		if panel is PanelContainer:
			(panel as PanelContainer).add_theme_stylebox_override("panel", panel_style)

	var banner_panel := get_node_or_null("IntermissionBanner/BannerPanel")
	if banner_panel is PanelContainer:
		var banner_style := panel_style.duplicate()
		banner_style.bg_color = Color(0.06, 0.04, 0.08, 0.88)
		banner_style.border_color = Color(0.95, 0.35, 0.22, 0.9)
		(banner_panel as PanelContainer).add_theme_stylebox_override("panel", banner_style)


func _set_ignore_mouse_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_ignore_mouse_recursive(child)
