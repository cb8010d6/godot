extends SceneTree
## Passive live-game observer. No camera, timing, physics, or input overrides.
var output := ""
var game_id := ""
var players_requested := 0
var map_requested := 0
var preflight := 0.0
var started_us := 0
var last_draw_us := 0
var last_sample_us := 0
var last_phase := -1
var play_started_us := 0
var capture_cooldown := 0
var captured := {}
var frames: FileAccess
var samples: FileAccess
var summary := {"status":"RUNNING", "phases":[], "captures":[], "errors":[], "observer":"passive; natural camera and real-time simulation"}

func _initialize() -> void:
	started_us = Time.get_ticks_usec()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--observe-output="): output = arg.trim_prefix("--observe-output=")
		elif arg.begins_with("--game="): game_id = arg.trim_prefix("--game=")
		elif arg.begins_with("--demo="): players_requested = int(arg.trim_prefix("--demo="))
		elif arg.begins_with("--map="): map_requested = int(arg.trim_prefix("--map="))
		elif arg.begins_with("--preflight-seconds="): preflight = float(arg.trim_prefix("--preflight-seconds="))
	_run.call_deferred()

func _optional(o: Object, key: StringName) -> Variant:
	for p: Dictionary in o.get_property_list():
		if p.name == key: return o.get(key)
	return null

func _v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func _write_summary() -> void:
	var f := FileAccess.open(output.path_join("observer.json"), FileAccess.WRITE)
	if f == null:
		push_error("Observer cannot write summary")
		return
	f.store_string(JSON.stringify(summary, "\t") + "\n")
	f.flush()
	f.close()

func _state(g: Node) -> Dictionary:
	var viewport_data: Array = []
	var player_data: Array = []
	for p: Variant in g.call("ordered"):
		var cam: Camera3D = p.cam
		var vp: Viewport = cam.get_viewport()
		var e: Environment = cam.environment if cam.environment != null else vp.find_world_3d().environment
		var env := {"pt": null, "ddgi": null}
		if e != null:
			env.pt = _optional(e, &"pathtracing_enabled")
			env.ddgi = _optional(e, &"ddgi_enabled")
		var body: Variant = p.data.sk
		player_data.append({"slot":p.c.player, "position":_v3(body.pos), "draw_position":_v3(body.draw_pos), "visual_rig_position":_v3(body.rig.global_position), "course_progress":body.s(), "speed":body.current_speed(), "camera_position":_v3(cam.global_position), "camera_forward":_v3(-cam.global_basis.z), "camera_fov":cam.fov, "camera_keep_aspect":cam.keep_aspect, "camera_projection":cam.projection, "camera_near":cam.near, "camera_far":cam.far, "score":p.score})
		viewport_data.append({"path":str(vp.get_path()), "camera":str(cam.get_path()), "size":[vp.size.x, vp.size.y], "scaling":vp.scaling_3d_mode, "scale":vp.scaling_3d_scale, "sharpness":vp.fsr_sharpness, "msaa":vp.msaa_3d, "screen_space_aa":vp.screen_space_aa, "fg":_optional(vp, &"frame_generation"), "environment":env})
	return {"at_seconds":float(Time.get_ticks_usec()-started_us)/1000000.0, "phase":g.get("phase"), "phase_time":g.get("phase_time"), "game":g.call("game_id"), "map":g.get("map_index"), "players":player_data, "viewports":viewport_data, "settings":{"upscale":RSSettings.upscale, "effective_upscale":RSSettings.effective_upscale(), "quality":RSSettings.quality, "hdr":RSSettings.hdr, "lighting":RSSettings.nvidia_lighting, "preset":RSSettings.nvidia_preset, "nis":RSSettings.nvidia_sharpness, "fg":RSSettings.nvidia_fg}, "dlss_available":RSNvidia.dlss_available(), "fg_status":RSNvidia.fg_status(), "window":{"focused":DisplayServer.window_is_focused(), "vsync":DisplayServer.window_get_vsync_mode(), "mode":DisplayServer.window_get_mode(), "max_fps":Engine.max_fps}}

func _capture(name: String) -> void:
	var img := root.get_texture().get_image()
	if img == null or img.is_empty():
		summary.errors.append("Empty image: " + name)
		return
	var path := output.path_join(name + ".png")
	var err := img.save_png(path)
	if err != OK:
		summary.errors.append("Image save error: " + name + " " + str(err))
		return
	summary.captures.append({"name":name, "sha256":FileAccess.get_sha256(path), "width":img.get_width(), "height":img.get_height(), "at_seconds":float(Time.get_ticks_usec()-started_us)/1000000.0})
	capture_cooldown = 3

func _run() -> void:
	if output.is_empty() or game_id not in ["skate", "ski"] or players_requested not in [1,4] or OS.get_environment("RS_TEST_MODE") != "1" or DisplayServer.get_name() == "headless":
		push_error("Observer arguments/environment invalid")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Observer output directory failed")
		quit(2)
		return
	frames = FileAccess.open(output.path_join("frames.csv"), FileAccess.WRITE)
	samples = FileAccess.open(output.path_join("samples.jsonl"), FileAccess.WRITE)
	if frames == null or samples == null:
		push_error("Observer output files failed")
		quit(2)
		return
	frames.store_line("seconds,frame_ms,phase,play_seconds,focused,excluded,capture")
	summary["engine"] = Engine.get_version_info()
	summary["gpu"] = RenderingServer.get_video_adapter_name()
	summary["driver"] = RenderingServer.get_current_rendering_driver_name()
	summary["rendering_method"] = RenderingServer.get_current_rendering_method()
	summary["physics"] = ProjectSettings.get_setting("physics/3d/physics_engine")
	summary["ticks"] = Engine.physics_ticks_per_second
	summary["resolution"] = [root.size.x,root.size.y]
	summary["scaling_enums"] = {"native":Viewport.SCALING_3D_MODE_BILINEAR, "fsr":Viewport.SCALING_3D_MODE_FSR2, "dlss":ClassDB.class_get_integer_constant("Viewport", "SCALING_3D_MODE_DLSS") if ClassDB.class_has_integer_constant("Viewport", "SCALING_3D_MODE_DLSS") else -1}
	summary["preflight_seconds_after_play"] = preflight
	summary["disable_fg_plugin"] = OS.get_environment("GODOT_STREAMLINE_DISABLE_DLSS_G")
	summary["disable_ota"] = OS.get_environment("GODOT_STREAMLINE_DISABLE_OTA")
	var scene: PackedScene = load("res://scenes/" + game_id + "/" + game_id + "_game.tscn")
	if scene == null:
		push_error("Cannot load actual game scene")
		quit(2)
		return
	var g: Node = scene.instantiate()
	root.add_child(g)
	current_scene = g
	_write_summary()
	while is_instance_valid(g):
		await process_frame
		await RenderingServer.frame_post_draw
		if not is_instance_valid(g): break
		var now := Time.get_ticks_usec()
		var phase: int = g.get("phase")
		if phase != last_phase:
			last_phase = phase
			summary.phases.append({"phase":phase, "at_seconds":float(now-started_us)/1000000.0})
			if phase == 2: play_started_us = now
			if phase == 3: summary.status = "RESULTS_OBSERVED"
			_write_summary()
		var play_seconds := float(now-play_started_us)/1000000.0 if play_started_us > 0 and phase == 2 else 0.0
		var capture := ""
		if phase == 2 and play_seconds >= 3.0 and not captured.has("play_start"): capture = "play_start"
		elif phase == 2 and play_seconds >= 10.0 and not captured.has("play_10s"): capture = "play_10s"
		elif phase == 2 and play_seconds >= 20.0 and not captured.has("play_20s"): capture = "play_20s"
		elif phase == 3 and not captured.has("results"): capture = "results"
		var focused := DisplayServer.window_is_focused()
		var excluded := phase != 2 or play_seconds < 10.0 or not focused or capture_cooldown > 0 or not capture.is_empty()
		if last_draw_us > 0:
			frames.store_line("%.6f,%.6f,%d,%.6f,%d,%d,%s" % [float(now-started_us)/1000000.0,float(now-last_draw_us)/1000.0,phase,play_seconds,int(focused),int(excluded),capture])
		last_draw_us = now
		if capture_cooldown > 0: capture_cooldown -= 1
		if not capture.is_empty():
			captured[capture] = true
			_capture(capture)
		if now-last_sample_us >= 1000000:
			var state := _state(g)
			samples.store_string(JSON.stringify(state) + "\n")
			samples.flush()
			frames.flush()
			last_sample_us = now
			summary["latest"] = state
			_write_summary()
			capture_cooldown = maxi(capture_cooldown, 3)
		if preflight > 0.0 and play_started_us > 0 and float(now-play_started_us)/1000000.0 >= preflight:
			summary.status = "STARTUP_ONLY"
			_write_summary()
			frames.close()
			samples.close()
			print("OBSERVER_STARTUP_ONLY")
			RSExit.quit(self, 0)
			return
