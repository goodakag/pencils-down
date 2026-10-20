shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Paper page: rendered PDF page x procedural fiber, graphite ink on top, page curl for flips.
uniform sampler2D page_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D ink_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_page = true;
uniform vec3 paper_tint : source_color = vec3(0.969, 0.957, 0.925);
uniform vec3 graphite : source_color = vec3(0.16, 0.158, 0.165);
// Page curl (see systems/packet/page_curl.gd, which does the same maths for picking and tests).
// The sheet folds along the line through fold_origin with normal fold_normal (page-local XZ,
// metres); paper past it wraps round a cylinder and comes back face down.
uniform vec2 fold_origin = vec2(0.0, 1.0);
uniform vec2 fold_normal = vec2(0.0, 1.0);
uniform float fold_radius = 0.016;
uniform float lift : hint_range(0.0, 1.0) = 0.0;   // hover: the grabbable corner rises a touch
uniform vec2 page_size = vec2(0.2159, 0.2794);
uniform float bleed = 0.07;
uniform float drape_z = -10.0;  // page-local z of the desk's far edge; turned paper bends down past it                         // how much print shows through from the front

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	vec2 p = VERTEX.xz;
	float d = dot(p - fold_origin, fold_normal);
	vec3 v = VERTEX;
	vec3 n = vec3(0.0, 1.0, 0.0);
	if (d > 0.0) {
		vec2 foot = p - fold_normal * d;
		float arc = PI * fold_radius;
		if (d < arc) {
			float a = d / fold_radius;
			vec2 q = foot + fold_normal * (fold_radius * sin(a));
			v = vec3(q.x, VERTEX.y + fold_radius * (1.0 - cos(a)), q.y);
			n = vec3(-fold_normal.x * sin(a), cos(a), -fold_normal.y * sin(a));
		} else {
			vec2 q = foot - fold_normal * (d - arc);
			float h = mix(2.0 * fold_radius, 0.0007, smoothstep(0.0, 5.0 * fold_radius, d - arc));
			if (q.y < drape_z) {
				// Hanging over the far edge of the desk.
				float over = drape_z - q.y;
				q.y = drape_z - over * 0.34;
				h -= over * 0.94;
			}
			v = vec3(q.x, VERTEX.y + h, q.y);
			n = vec3(0.0, -1.0, 0.0);
		}
	}
	// Hover lift at the bottom-right corner, where the hand would take hold.
	vec2 c = (p / page_size) + 0.5;  // 0..1 across and down the page
	float corner = clamp((c.x - 0.55) * 2.2, 0.0, 1.0) * clamp((c.y - 0.55) * 2.2, 0.0, 1.0);
	v.y += lift * corner * corner * 0.009;
	VERTEX = v;
	NORMAL = n;
}

void fragment() {
	float fiber = 0.94 + 0.04 * noise(UV * vec2(900.0, 1100.0)) + 0.02 * noise(UV * vec2(80.0, 70.0));
	vec3 paper = paper_tint * fiber;
	vec3 col = paper;
	float rough = 0.92;
	if (!FRONT_FACING && has_page) {
		// The back of the sheet: blank, with the print faintly showing through.
		float lum = dot(texture(page_tex, UV).rgb, vec3(0.333));
		col = paper * mix(1.0, lum, bleed);
	}
	if (FRONT_FACING) {
		if (has_page) {
			col = texture(page_tex, UV).rgb * paper;
		}
		// The ink viewport has no mipmaps: average 4 taps across the pixel footprint so thin
		// pencil lines fade smoothly with distance instead of breaking up.
		vec2 fw = fwidth(UV) * 0.35;
		float ia = texture(ink_tex, UV + vec2(-fw.x, -fw.y)).a + texture(ink_tex, UV + vec2(fw.x, -fw.y)).a
			+ texture(ink_tex, UV + vec2(-fw.x, fw.y)).a + texture(ink_tex, UV + vec2(fw.x, fw.y)).a;
		ia = max(ia * 0.25, texture(ink_tex, UV).a * 0.8);
		float a = clamp(ia * 1.25, 0.0, 1.0) * (0.85 + 0.15 * noise(UV * 2400.0));
		col = mix(col, graphite, a);
		rough = mix(0.92, 0.55, a);  // graphite has a faint sheen
	}
	ALBEDO = col;
	BACKLIGHT = paper * 0.55;  // paper is thin: light shows through a lifted sheet
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
