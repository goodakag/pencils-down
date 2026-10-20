class_name PageCurl
extends RefCounted
## How a sheet bends while it is turned over its stapled top edge.
##
## Coordinates are the page's own flat plane in metres: x to the right, z toward the reader, the
## page centred on the origin, so the top edge (held by the staple) is z = -size.y / 2.
## The sheet folds along a line (a point `origin` on it and a unit `normal` pointing toward the
## part that lifts). Paper past the line wraps around a cylinder of `radius` and comes back face
## down on the other side, exactly like a page being turned by hand. `paper_page.gdshader` does the
## same maths per vertex; keep the two in step.

const DEFAULT_RADIUS := 0.016
const RESTING := 0.0007  # height of a turned sheet lying on whatever is under it

var size: Vector2
var origin: Vector2
var normal: Vector2 = Vector2(0, 1)
var radius: float = DEFAULT_RADIUS
var drape_z: float = -10.0  # the desk's far edge: turned paper hangs down past it


func _init(page_size: Vector2 = Vector2(0.2159, 0.2794)) -> void:
	size = page_size
	origin = Vector2(0, size.y * 0.5 + 0.001)


## Lying flat, nothing lifted.
static func flat(page_size: Vector2) -> PageCurl:
	return PageCurl.new(page_size)


## Turned all the way over the top edge.
static func turned(page_size: Vector2) -> PageCurl:
	var c := PageCurl.new(page_size)
	c.origin = Vector2(0, -page_size.y * 0.5)
	c.normal = Vector2(0, 1)
	return c


## The hand grabbed the sheet at `grab` (a point on the flat sheet) and is now at `at`: the fold is
## the line halfway between them, so the grabbed point lands under the hand.
static func from_drag(page_size: Vector2, grab: Vector2, at: Vector2, r: float = DEFAULT_RADIUS) -> PageCurl:
	var c := PageCurl.new(page_size)
	c.radius = r
	var pull := grab - at
	if pull.length() < 1e-5 or pull.y <= 0.0:
		return c  # pushing the sheet toward the reader doesn't lift it
	c.normal = pull.normalized()
	# Wrapping round the cylinder takes up π·r of paper, so the fold sits π·r/2 further from the
	# grab than halfway; small tugs blend that in so the corner only peels a little at first.
	var len := pull.length()
	var d := len * 0.5 + PI * r * 0.5 * smoothstep(0.0, 2.0 * PI * r, len)
	c.origin = grab - c.normal * d
	c.clamp_to_hinge()
	return c


## The stapled top edge never lifts: slide the fold away until both top corners stay flat.
func clamp_to_hinge() -> void:
	var top := -size.y * 0.5
	var worst := maxf(signed_distance(Vector2(-size.x * 0.5, top)), signed_distance(Vector2(size.x * 0.5, top)))
	if worst > 0.0:
		origin += normal * worst


## > 0 past the fold (lifting), <= 0 still flat.
func signed_distance(p: Vector2) -> float:
	return (p - origin).dot(normal)


## Where flat point `p` ends up: x, height above the desk, z.
func map(p: Vector2) -> Vector3:
	var d := signed_distance(p)
	if d <= 0.0:
		return Vector3(p.x, 0.0, p.y)
	var foot := p - normal * d
	var arc := PI * radius
	if d < arc:
		var a := d / radius
		var q := foot + normal * (radius * sin(a))
		return Vector3(q.x, radius * (1.0 - cos(a)), q.y)
	var back := foot - normal * (d - arc)
	var h := lerpf(2.0 * radius, RESTING, smoothstep(0.0, 5.0 * radius, d - arc))
	if back.y < drape_z:
		var over := drape_z - back.y
		back.y = drape_z - over * 0.34
		h -= over * 0.94
	return Vector3(back.x, h, back.y)


## 0 = flat, 1 = turned over, by how far the fold has travelled up the sheet.
func progress() -> float:
	var dc := signed_distance(Vector2.ZERO)
	return clampf((dc + size.y * 0.5) / size.y, 0.0, 1.0)


## Blend toward `other` (for the finishing and falling-back animations).
func lerped(other: PageCurl, t: float) -> PageCurl:
	var c := PageCurl.new(size)
	c.radius = lerpf(radius, other.radius, t)
	c.origin = origin.lerp(other.origin, t)
	var n := normal.slerp(other.normal, t)
	c.normal = n.normalized() if n.length() > 1e-5 else other.normal
	return c


## Letting go: past halfway the page finishes turning; a quick flick finishes it sooner.
## `speed` is how fast the hand was moving toward the top edge (metres per second).
static func should_complete(p: float, speed: float) -> bool:
	if speed > 0.35 and p > 0.12:
		return true
	if speed < -0.35:
		return false
	return p >= 0.5


## Turning back: grabbing a turned-over sheet anywhere means holding its bottom edge.
static func unturn_drag(page_size: Vector2, at: Vector2, grab_x: float, r: float = DEFAULT_RADIUS) -> PageCurl:
	var c := from_drag(page_size, Vector2(grab_x, page_size.y * 0.5), at, r)
	if c.progress() <= 0.0 and at.y < page_size.y * 0.5:
		return turned(page_size)
	return c
