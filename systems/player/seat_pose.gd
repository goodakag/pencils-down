class_name SeatPose
extends RefCounted
## Where the seated player's eyes are, relative to the desk-surface origin (the centre of the test
## packet; +Y up, the front of the room toward -Z). Measured from a real student desk: eyes about
## 44 cm above the desk top and a little behind its near edge.

const DESK_EYE := Vector3(0.0, 0.32, 0.25)
const DESK_LOOK := Vector3(0.0, 0.0, 0.015)
const LEAN_EYE := Vector3(0.0, 0.17, 0.11)  # leaning right over the paper
const UPRIGHT_EYE := Vector3(0.0, 0.47, 0.42)
const LOOK_UP_FOV := 34.0   # looking up = focusing on the clock, so the view narrows
const FREE_YAW := 28.0
const FREE_PITCH := 12.0


## Writing at the desk. `lean` 0..1 brings the head down toward `focus`, a point on the desk in the
## same space (usually under the cursor).
static func desk(lean: float, focus: Vector3) -> Transform3D:
	var l := clampf(lean, 0.0, 1.0)
	var f := Vector3(focus.x, 0.0, focus.z)
	var look := DESK_LOOK.lerp(f, l * 0.9)
	var eye := DESK_EYE.lerp(LEAN_EYE + f * Vector3(0.75, 0.0, 0.75), l)
	return Transform3D(Basis(), eye).looking_at(look, Vector3.UP)


## Sitting up and looking at `target` (the clock), with the mouse adding a little free look
## (`free_look` −1..1 on each axis).
static func look_up(target: Vector3, free_look: Vector2) -> Transform3D:
	var base := Transform3D(Basis(), UPRIGHT_EYE).looking_at(target, Vector3.UP)
	var b := base.basis.rotated(Vector3.UP, deg_to_rad(-free_look.x * FREE_YAW))
	b = b * Basis(Vector3.RIGHT, deg_to_rad(-free_look.y * FREE_PITCH))
	return Transform3D(b, base.origin)


## Is `point` inside a camera's view? (vertical `fov_deg`, width/height `aspect`)
static func sees(cam: Transform3D, fov_deg: float, aspect: float, point: Vector3) -> bool:
	var local := cam.affine_inverse() * point
	if local.z >= 0.0:
		return false
	var t := tan(deg_to_rad(fov_deg) * 0.5)
	var depth := -local.z
	return absf(local.y) <= t * depth and absf(local.x) <= t * aspect * depth


## Small breathing and head-drift offset (metres), a smooth function of time.
static func sway(t: float) -> Vector3:
	return Vector3(sin(t * 0.37) * 0.0022 + sin(t * 0.91) * 0.0008,
		sin(t * 1.55) * 0.0016,
		sin(t * 0.23 + 1.0) * 0.0018)
