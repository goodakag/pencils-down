class_name EdgeLook
extends RefCounted
## Resting the cursor against the top edge of the screen for 0.35 s lifts the head (FNAF-style).

const BAND := 0.03
const DWELL := 0.35

var enabled: bool = true
var _held: float = 0.0


## mouse_y_norm: 0 at the top of the window, 1 at the bottom.
func update(mouse_y_norm: float, delta: float) -> bool:
	if not enabled or mouse_y_norm > BAND:
		_held = 0.0
		return false
	_held += delta
	return _held >= DWELL - 1e-6


func reset() -> void:
	_held = 0.0
