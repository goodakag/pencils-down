class_name WallClock
extends Node3D
## Digital LED wall clock above the board: black case, smoked front, glowing red seven-segment
## digits (unlit segments stay faintly visible, as on a real LED clock). Faces +Z.

const CASE_SIZE := Vector3(0.66, 0.25, 0.05)
const DIGIT_H := 0.16
const DIGIT_W := 0.085
const SEG_T := 0.017  # segment thickness
const LIT := Color(1.0, 0.13, 0.06)
const GHOST := Color(0.16, 0.03, 0.025)

var twelve_hour: bool = true

var _digits: Array = []  # 4 × Array[MeshInstance3D] (segments a..g)
var _colon: Array[MeshInstance3D] = []
var _pm: MeshInstance3D
var _lit_mat: StandardMaterial3D
var _ghost_mat: StandardMaterial3D
var _shown := ""
var _colon_on := true


func _init() -> void:
	_lit_mat = StandardMaterial3D.new()
	_lit_mat.albedo_color = LIT
	_lit_mat.emission_enabled = true
	_lit_mat.emission = LIT
	_lit_mat.emission_energy_multiplier = 4.0
	_lit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = GHOST
	_ghost_mat.roughness = 0.6

	var case := _box(CASE_SIZE, Vector3.ZERO, Color(0.05, 0.05, 0.055), 0.45)
	case.name = "Case"
	# Recessed dark face, then a glossy smoked cover in front of the digits.
	_box(Vector3(CASE_SIZE.x - 0.03, CASE_SIZE.y - 0.03, 0.004), Vector3(0, 0, CASE_SIZE.z * 0.5), Color(0.015, 0.012, 0.012), 0.8)
	var cover := _box(Vector3(CASE_SIZE.x - 0.03, CASE_SIZE.y - 0.03, 0.003), Vector3(0, 0, CASE_SIZE.z * 0.5 + 0.009), Color(0.05, 0.04, 0.04, 0.18), 0.05)
	var cm := cover.material_override as StandardMaterial3D
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.metallic_specular = 0.9
	cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var z := CASE_SIZE.z * 0.5 + 0.004
	var xs := [-0.225, -0.115, 0.04, 0.15]
	for x in xs:
		_digits.append(_build_digit(Vector3(x, 0.0, z)))
	for y in [0.035, -0.035]:
		var dot := _seg(Vector3(SEG_T, SEG_T, 0.003), Vector3(-0.037, y, z))
		_colon.append(dot)
	_pm = _seg(Vector3(SEG_T * 0.9, SEG_T * 0.9, 0.003), Vector3(0.235, -0.06, z))
	var pm_label := Label3D.new()
	pm_label.text = "PM"
	pm_label.font_size = 32
	pm_label.pixel_size = 0.0006
	pm_label.modulate = Color(0.45, 0.42, 0.4)
	pm_label.outline_size = 0
	pm_label.position = Vector3(0.262, -0.06, z + 0.001)
	add_child(pm_label)


func _build_digit(c: Vector3) -> Array:
	var w := DIGIT_W
	var h := DIGIT_H * 0.5
	var horiz := Vector3(w - SEG_T, SEG_T, 0.003)
	var vert := Vector3(SEG_T, h - SEG_T, 0.003)
	var segs: Array = []
	segs.append(_seg(horiz, c + Vector3(0, h, 0)))                       # a
	segs.append(_seg(vert, c + Vector3(w * 0.5, h * 0.5, 0)))            # b
	segs.append(_seg(vert, c + Vector3(w * 0.5, -h * 0.5, 0)))           # c
	segs.append(_seg(horiz, c + Vector3(0, -h, 0)))                      # d
	segs.append(_seg(vert, c + Vector3(-w * 0.5, -h * 0.5, 0)))          # e
	segs.append(_seg(vert, c + Vector3(-w * 0.5, h * 0.5, 0)))           # f
	segs.append(_seg(horiz, c))                                          # g
	# Real LED digits lean forward slightly.
	for s in segs:
		var m := s as MeshInstance3D
		m.position.x += (m.position.y - c.y) * 0.08
		m.rotation.z = -0.08 if m.mesh.size.y > m.mesh.size.x else 0.0
	return segs


func set_time(seconds_of_day: float) -> void:
	var text := WallClockMath.digital(seconds_of_day, twelve_hour)
	var colon := fposmod(seconds_of_day, 1.0) < 0.5  # the colon blinks once a second
	if text == _shown and colon == _colon_on:
		return
	_shown = text
	_colon_on = colon
	var digits := text.replace(":", "").lpad(4, " ")
	for i in 4:
		var mask := WallClockMath.segments(digits[i])
		var segs: Array = _digits[i]
		for s in 7:
			(segs[s] as MeshInstance3D).material_override = _lit_mat if mask & (1 << s) else _ghost_mat
	for d in _colon:
		d.material_override = _lit_mat if colon else _ghost_mat
	_pm.material_override = _lit_mat if (twelve_hour and WallClockMath.is_pm(seconds_of_day)) else _ghost_mat


## What the clock currently reads (for tests and screenshots).
func reading() -> String:
	return _shown


func _seg(size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _ghost_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, color: Color, rough: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	mi.material_override = m
	add_child(mi)
	return mi
