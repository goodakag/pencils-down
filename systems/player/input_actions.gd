class_name InputActions
extends RefCounted
## Default bindings (spec §5.8). Registered in code so Settings can rebind them later.

const MOUSE := "mouse"
const KEY := "key"

const DEFAULTS := {
	"draw": [MOUSE, MOUSE_BUTTON_LEFT],
	"erase": [MOUSE, MOUSE_BUTTON_RIGHT],
	"type_mode": [KEY, KEY_T],
	"turn_next": [KEY, KEY_D],
	"turn_prev": [KEY, KEY_A],
	"overview": [KEY, KEY_Q],
	"scratch": [KEY, KEY_TAB],
	"look_up": [KEY, KEY_SPACE],
	"hand_in": [KEY, KEY_H],
	"menu": [KEY, KEY_ESCAPE],
	"fidget": [KEY, KEY_F],
	"keys_note": [KEY, KEY_F1],
	"raise_hand": [KEY, KEY_R],
	"glance_down": [KEY, KEY_S],
}


static func ensure() -> void:
	for action in DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var spec: Array = DEFAULTS[action]
		if spec[0] == MOUSE:
			var e := InputEventMouseButton.new()
			e.button_index = spec[1]
			InputMap.action_add_event(action, e)
		else:
			var k := InputEventKey.new()
			k.physical_keycode = spec[1]
			InputMap.action_add_event(action, k)
	# Shortcuts with modifiers are checked directly in PlayerRig (Ctrl+Z / Ctrl+Y / Ctrl+[ ]).
