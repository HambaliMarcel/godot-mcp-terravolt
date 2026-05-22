@tool
extends RefCounted
class_name TerravoltBusLayoutWriter

## Persist AudioServer bus layout to the project default_bus_layout resource (task 21).

const LAYOUT_SETTING := "audio/buses/default_bus_layout"


static func layout_path() -> String:
	var p: Variant = ProjectSettings.get_setting(LAYOUT_SETTING, "")
	return str(p) if p != null and str(p) != "" else "res://default_bus_layout.tres"


static func persist_if_editor() -> void:
	if not OS.has_feature("editor"):
		return
	var path := layout_path()
	var res_path := path if path.begins_with("res://") else "res://%s" % path
	var layout := AudioBusLayout.new()
	for i in AudioServer.bus_count:
		layout.add_bus()
		layout.set_bus_name(i, AudioServer.get_bus_name(i))
		layout.set_bus_send(i, AudioServer.get_bus_send(i))
		layout.set_bus_volume_db(i, AudioServer.get_bus_volume_db(i))
		layout.set_bus_mute(i, AudioServer.is_bus_mute(i))
		layout.set_bus_solo(i, AudioServer.is_bus_solo(i))
		layout.set_bus_bypass_effects(i, AudioServer.is_bus_bypassing_effects(i))
		for j in AudioServer.get_bus_effect_count(i):
			var eff := AudioServer.get_bus_effect(i, j)
			if eff != null:
				layout.add_bus_effect(i, eff.duplicate(true))
	var err := ResourceSaver.save(layout, res_path)
	if err == OK:
		ProjectSettings.set_setting(LAYOUT_SETTING, res_path)
		ProjectSettings.save()
