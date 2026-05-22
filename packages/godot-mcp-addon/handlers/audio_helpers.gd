@tool
extends RefCounted
class_name TerravoltAudioHelpers

## AudioServer bus helpers (task 21).

const PREVIEW_MAX_SECONDS := 10.0
const _Res := preload("./resource_helpers.gd")
const _BusWriter := preload("../services/bus_layout_writer.gd")

const EFFECT_KINDS := {
	"Reverb": "AudioEffectReverb",
	"Delay": "AudioEffectDelay",
	"Compressor": "AudioEffectCompressor",
	"Chorus": "AudioEffectChorus",
	"Limiter": "AudioEffectLimiter",
	"EQ6": "AudioEffectEQ6",
	"EQ10": "AudioEffectEQ10",
	"EQ21": "AudioEffectEQ21",
	"Distortion": "AudioEffectDistortion",
	"PitchShift": "AudioEffectPitchShift",
	"Phaser": "AudioEffectPhaser",
	"PanRecorder": "AudioEffectRecord",
	"Record": "AudioEffectRecord",
}


static func ensure_bus_layout_loaded() -> void:
	if AudioServer.bus_count > 1:
		return
	var path: Variant = ProjectSettings.get_setting("audio/buses/default_bus_layout", "")
	if path == null or str(path).is_empty():
		return
	var layout := load(str(path)) as AudioBusLayout
	if layout != null:
		AudioServer.set_bus_layout(layout)


static func resolve_bus_index(bus: Variant) -> int:
	if typeof(bus) == TYPE_INT or typeof(bus) == TYPE_FLOAT:
		var idx := int(bus)
		if idx >= 0 and idx < AudioServer.bus_count:
			return idx
		return -1
	var bus_name := str(bus)
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == bus_name:
			return i
	return -1


static func list_buses() -> Dictionary:
	ensure_bus_layout_loaded()
	var out: Array = []
	for i in AudioServer.bus_count:
		out.append(_bus_info(i))
	return {"ok": true, "result": {"buses": out}}


static func _bus_info(index: int) -> Dictionary:
	var send_name: Variant = str(AudioServer.get_bus_send(index))
	if send_name == "":
		send_name = null
	var effects: Array = []
	for e in AudioServer.get_bus_effect_count(index):
		var fx: AudioEffect = AudioServer.get_bus_effect(index, e)
		var kind := fx.get_class() if fx != null else "Unknown"
		if kind.begins_with("AudioEffect"):
			kind = kind.substr("AudioEffect".length())
		effects.append({
			"index": e,
			"kind": kind,
			"enabled": AudioServer.is_bus_effect_enabled(index, e),
			"params": {},
		})
	return {
		"index": index,
		"name": AudioServer.get_bus_name(index),
		"volume_db": AudioServer.get_bus_volume_db(index),
		"mute": AudioServer.is_bus_mute(index),
		"solo": _bus_solo(index),
		"bypass_effects": AudioServer.is_bus_bypassing_effects(index),
		"send_to": send_name,
		"effects": effects,
	}


static func _bus_solo(index: int) -> bool:
	return AudioServer.is_bus_solo(index)


static func add_bus(params: Dictionary) -> Dictionary:
	ensure_bus_layout_loaded()
	var bus_name := str(params.get("name", "")).strip_edges()
	if bus_name.is_empty():
		return {"ok": false, "code": -33971, "message": "audio.bus_unknown"}
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i) == bus_name:
			return {"ok": false, "code": -33970, "message": "audio.bus_name_exists"}
	var at := int(params.get("index", -1))
	if at < 0:
		at = AudioServer.bus_count
	AudioServer.add_bus(at)
	AudioServer.set_bus_name(at, bus_name)
	var send_to := str(params.get("send_to", "Master"))
	if resolve_bus_index(send_to) >= 0:
		AudioServer.set_bus_send(at, send_to)
	_BusWriter.persist_if_editor()
	return {
		"ok": true,
		"result": {
			"added": true,
			"index": at,
			"name": bus_name,
			"state": "live",
			"revision": str(Time.get_ticks_msec()),
		},
	}


static func remove_bus(params: Dictionary) -> Dictionary:
	var idx := resolve_bus_index(params.get("name", params.get("index", "")))
	if idx < 0:
		return {"ok": false, "code": -33971, "message": "audio.bus_unknown"}
	if AudioServer.get_bus_name(idx) == "Master":
		return {"ok": false, "code": -33972, "message": "audio.cannot_remove_master"}
	var reassign_to := str(params.get("reassign_sends_to", "Master"))
	var reassigned := 0
	for i in AudioServer.bus_count:
		if str(AudioServer.get_bus_send(i)) == AudioServer.get_bus_name(idx):
			AudioServer.set_bus_send(i, reassign_to)
			reassigned += 1
	var removed_name := AudioServer.get_bus_name(idx)
	AudioServer.remove_bus(idx)
	_BusWriter.persist_if_editor()
	return {
		"ok": true,
		"result": {"removed": true, "name": removed_name, "index": idx, "reassigned_count": reassigned},
	}


static func set_bus(params: Dictionary) -> Dictionary:
	var idx := resolve_bus_index(params.get("bus", ""))
	var patch: Dictionary = params.get("patch", {}) as Dictionary
	if idx < 0:
		return {"ok": false, "code": -33971, "message": "audio.bus_unknown"}
	var applied: Dictionary = {}
	if patch.has("volume_db"):
		var before := AudioServer.get_bus_volume_db(idx)
		var after := float(patch["volume_db"])
		AudioServer.set_bus_volume_db(idx, after)
		applied["volume_db"] = {"before": before, "after": after}
	if patch.has("mute"):
		AudioServer.set_bus_mute(idx, bool(patch["mute"]))
		applied["mute"] = {"before": null, "after": bool(patch["mute"])}
	if patch.has("solo"):
		AudioServer.set_bus_solo(idx, bool(patch["solo"]))
		applied["solo"] = {"before": null, "after": bool(patch["solo"])}
	if patch.has("bypass_effects"):
		AudioServer.set_bus_bypass_effects(idx, bool(patch["bypass_effects"]))
		applied["bypass_effects"] = {"before": null, "after": bool(patch["bypass_effects"])}
	if patch.has("send_to"):
		var send_name := str(patch["send_to"])
		if resolve_bus_index(send_name) >= 0:
			AudioServer.set_bus_send(idx, send_name)
			applied["send_to"] = {"before": null, "after": send_name}
	_BusWriter.persist_if_editor()
	return {"ok": true, "result": {"updated": true, "applied": applied}}


static func add_effect(params: Dictionary) -> Dictionary:
	var idx := resolve_bus_index(params.get("bus", ""))
	if idx < 0:
		return {"ok": false, "code": -33971, "message": "audio.bus_unknown"}
	var kind := str(params.get("kind", ""))
	var cls := str(EFFECT_KINDS.get(kind, ""))
	if cls.is_empty() or not ClassDB.class_exists(cls):
		return {"ok": false, "code": -33973, "message": "audio.effect_kind_unknown"}
	var fx: AudioEffect = ClassDB.instantiate(cls)
	var effect_params: Dictionary = params.get("params", {}) as Dictionary
	for k in effect_params.keys():
		fx.set(str(k), effect_params[k])
	var pos := int(params.get("position", -1))
	if pos < 0:
		pos = AudioServer.get_bus_effect_count(idx)
	AudioServer.add_bus_effect(idx, fx, pos)
	_BusWriter.persist_if_editor()
	return {
		"ok": true,
		"result": {
			"added": true,
			"bus": AudioServer.get_bus_name(idx),
			"effect_index": pos,
			"kind": kind,
			"state": "live",
			"revision": str(Time.get_ticks_msec()),
		},
	}


static func preview_play(params: Dictionary, tree: SceneTree) -> Dictionary:
	if DisplayServer.get_name() == "headless":
		return {"ok": false, "code": -33974, "message": "audio.preview_unavailable"}
	var stream_path := str(params.get("stream_path", ""))
	var path := _Res.resolve_path(stream_path)
	if not ResourceLoader.exists(path):
		return {"ok": false, "code": -33800, "message": "resource.path_not_found"}
	var stream: AudioStream = ResourceLoader.load(path)
	if stream == null:
		return {"ok": false, "code": -33800, "message": "resource.path_not_found"}
	if tree == null:
		return {"ok": false, "code": -33974, "message": "audio.preview_unavailable"}
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = float(params.get("volume_db", 0.0))
	player.pitch_scale = float(params.get("pitch_scale", 1.0))
	var bus_name := str(params.get("bus", "Master"))
	if resolve_bus_index(bus_name) >= 0:
		player.bus = bus_name
	tree.root.add_child(player)
	player.play()
	var stream_len := stream.get_length()
	var duration_s := float(params.get("duration_s", 0.0))
	var max_s := mini(PREVIEW_MAX_SECONDS, maxf(0.05, duration_s if duration_s > 0 else minf(stream_len, 0.5)))
	var deadline := Time.get_ticks_msec() + int(max_s * 1000.0) + 250
	while Time.get_ticks_msec() < deadline and player.is_playing():
		OS.delay_msec(5)
	player.queue_free()
	return {
		"ok": true,
		"result": {
			"played": true,
			"duration_played_s": max_s,
			"finished_at": Time.get_datetime_string_from_system(true),
		},
	}
