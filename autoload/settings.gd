extends Node
## Autoload "Settings": loads user://settings.cfg on start and saves on every change.

signal changed(key: String)

var store := SettingsStore.new()


func _ready() -> void:
	store.load()


func get_value(key: String) -> Variant:
	return store.get_value(key)


func set_value(key: String, v: Variant) -> void:
	store.set_value(key, v)
	store.save()
	changed.emit(key)


func push_recent(path: String) -> void:
	store.push_recent(path)
	store.save()
