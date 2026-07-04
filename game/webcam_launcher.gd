extends Node

## Starts pose_stream.py when playing in Webcam control mode.

const TOOLS_DIR := "res://tools/camera-controller"
const POSE_SCRIPT := "pose_stream.py"

var _pid := -1


func _ready() -> void:
	tree_exiting.connect(stop)


func _exit_tree() -> void:
	stop()


func is_running() -> bool:
	return _pid > 0 and OS.is_process_running(_pid)


func start() -> void:
	stop()
	if not ControlMode.is_webcam():
		return

	var python := _resolve_python()
	var script := ProjectSettings.globalize_path(TOOLS_DIR.path_join(POSE_SCRIPT))
	var args := PackedStringArray([script, "--game-bridge", "--no-display"])
	_pid = OS.create_process(python, args, false)
	if _pid <= 0:
		push_error("WebcamLauncher: failed to start pose_stream.py")
	else:
		print("WebcamLauncher: pose_stream pid=", _pid)


func stop() -> void:
	if _pid > 0:
		if OS.is_process_running(_pid):
			OS.kill(_pid)
		_pid = -1


func _resolve_python() -> String:
	var tools := ProjectSettings.globalize_path(TOOLS_DIR)
	var venv_python := tools.path_join(".venv/bin/python")
	if FileAccess.file_exists(venv_python):
		return venv_python

	print("WebcamLauncher: bootstrapping Python venv (first run may take a minute)...")
	var output: Array = []
	var code := OS.execute("/bin/bash", [tools.path_join("run_for_game.sh"), "--setup-only"], output, true, false)
	if code != 0:
		push_warning("WebcamLauncher: venv setup exit code %d" % code)

	if FileAccess.file_exists(venv_python):
		return venv_python

	push_warning("WebcamLauncher: falling back to system python3")
	return "python3"
