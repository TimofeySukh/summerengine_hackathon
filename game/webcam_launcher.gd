extends Node

## Starts pose_stream.py when playing in Webcam control mode.

const TOOLS_DIR := "res://tools/camera-controller"
const RUN_SCRIPT := "run_for_game.sh"
const POSE_MATCH := "pose_stream.py --game-bridge"

var _pid := -1
var _external_launch := false


func _ready() -> void:
	tree_exiting.connect(stop)


func _exit_tree() -> void:
	stop()


func is_running() -> bool:
	if _external_launch:
		return _is_pose_stream_running()
	return _pid > 0 and OS.is_process_running(_pid)


func start() -> void:
	stop()
	if not ControlMode.is_webcam():
		return

	var tools := ProjectSettings.globalize_path(TOOLS_DIR)
	var script := tools.path_join(RUN_SCRIPT)
	if not FileAccess.file_exists(script):
		push_error("WebcamLauncher: missing %s" % script)
		return

	_ensure_venv(tools)

	if OS.get_name() == "macOS":
		_launch_macos_terminal(tools)
		return

	_pid = OS.create_process("/bin/bash", PackedStringArray([script]), false)
	if _pid <= 0:
		push_error("WebcamLauncher: failed to start pose_stream")
	else:
		print("WebcamLauncher: Katana Pose pid=", _pid)


func stop() -> void:
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1
	_external_launch = false
	if _is_pose_stream_running():
		OS.execute("pkill", ["-f", POSE_MATCH], [], true, false)


func _launch_macos_terminal(tools: String) -> void:
	# OpenCV needs a real GUI context; spawning from Summer Engine is unreliable on macOS.
	var shell_cmd := "cd '%s' && ./run_for_game.sh" % tools.replace("'", "'\\''")
	var osa := "tell application \"Terminal\" to do script \"%s\"" % shell_cmd.replace("\"", "\\\"")
	var code := OS.execute("osascript", ["-e", osa], [], true, false)
	if code != 0:
		push_error("WebcamLauncher: could not open Terminal (run: cd %s && ./run_for_game.sh)" % tools)
		return
	_external_launch = true
	print("WebcamLauncher: opened Katana Pose in Terminal")


func _is_pose_stream_running() -> bool:
	var output: Array = []
	var code := OS.execute("pgrep", ["-f", POSE_MATCH], output, true, false)
	return code == 0


func _ensure_venv(tools: String) -> void:
	var venv_python := tools.path_join(".venv/bin/python")
	if FileAccess.file_exists(venv_python):
		return

	print("WebcamLauncher: bootstrapping Python venv (first run may take a minute)...")
	var output: Array = []
	var code := OS.execute("/bin/bash", [tools.path_join(RUN_SCRIPT), "--setup-only"], output, true, false)
	if code != 0:
		push_warning("WebcamLauncher: venv setup exit code %d" % code)
