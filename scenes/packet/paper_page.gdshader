shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Paper page: rendered PDF page x procedural fiber, graphite ink on top, page curl for flips.
uniform sampler2D page_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D ink_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_page = true;
uniform vec3 paper_tint : source_color = vec3(0.969, 0.957, 0.925);
uniform vec3 graphite : source_color = vec3(0.16, 0.158, 0.165);
uniform float curl : hint_range(0.0, 1.0) = 0.0;  // 0 = flat, 1 = flipped over the top edge
uniform float page_len = 0.2794;                   // metres, along local Z (top at -len/2)
uniform float lift : hint_range(0.0, 1.0) = 0.0;   // bottom-right corner lift

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	float top = -page_len * 0.5;
	float d = VERTEX.z - top;  // distance from the hinge (top edge)
	float t = d / page_len;
	// Rotate around the top edge; the far end lags a little so the sheet bends like paper.
	float a = curl * PI * mix(1.0, 0.92, t * (1.0 - curl));
	float bow = sin(curl * PI) * 0.035 * t * t;
	vec3 v = VERTEX;
	v.z = top + d * cos(a);
	v.y = VERTEX.y + d * sin(a) + bow;
	// Rotate the normal with the sheet so a lifted page is lit correctly on both sides.
	NORMAL = vec3(0.0, cos(a), -sin(a));
	// Corner lift: a slight curl at the bottom-right where fingers grab the page.
	float corner = clamp((VERTEX.x / 0.2) + t - 1.2, 0.0, 1.0);
	v.y += lift * corner * corner * 0.012;
	VERTEX = v;
}

void fragment() {
	float fiber = 0.94 + 0.04 * noise(UV * vec2(900.0, 1100.0)) + 0.02 * noise(UV * vec2(80.0, 70.0));
	vec3 paper = paper_tint * fiber;
	vec3 col = paper;
	float rough = 0.92;
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
