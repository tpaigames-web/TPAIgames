@tool
extends EditorPlugin

const ADS_PLUGIN = preload("res://addons/admob/android/bin/ads/poing_godot_admob_ads.gd")

var _ads_export_plugin: EditorExportPlugin = null


func _enter_tree() -> void:
	_ads_export_plugin = ADS_PLUGIN.new()
	add_export_plugin(_ads_export_plugin)


func _exit_tree() -> void:
	if _ads_export_plugin:
		remove_export_plugin(_ads_export_plugin)
		_ads_export_plugin = null
