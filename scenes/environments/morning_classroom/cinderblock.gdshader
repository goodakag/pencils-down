shader_type spatial;
// Painted concrete block wall: 16" x 8" blocks in running bond, concave mortar joints, satin paint.
// Works in world space so any wall box keeps the right block size.

uniform vec3 paint : source_color = vec3(0.92, 0.88, 0.79);
uniform sampler2D grain : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 block = vec2(0.406, 0.203);
uniform float joint = 0.011;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	// Wall-plane coordinates: walls facing X use (z, y), walls facing Z use (x, y).
	vec2 uv = abs(wnrm.x) > 0.5 ? wpos.zy : wpos.xy;
	float row = floor(uv.y / block.y);
	vec2 b = vec2(uv.x / block.x + 0.5 * mod(row, 2.0), uv.y / block.y);
	vec2 cell = floor(b);
	vec2 f = fract(b) * block;            // metres inside the block
	vec2 edge = min(f, block - f);
	float d = min(edge.x, edge.y);
	float groove = 1.0 - smoothstep(0.0, joint, d);
	// Slope of the concave joint drives the normal.
	vec2 g = vec2(0.0);
	if (edge.x < edge.y) g.x = (f.x < block.x * 0.5 ? 1.0 : -1.0); else g.y = (f.y < block.y * 0.5 ? 1.0 : -1.0);
	float slope = groove * (1.0 - groove) * 4.0;
	float gr = texture(grain, uv * 0.8).r;
	float fine = texture(grain, uv * 3.1).g;
	float tone = 0.94 + 0.06 * hash(cell) + (gr - 0.5) * 0.12 + (fine - 0.5) * 0.08;
	ALBEDO = paint * tone * (1.0 - groove * 0.18);
	ROUGHNESS = 0.62 + groove * 0.2 - (fine - 0.5) * 0.1;
	AO = 1.0 - groove * 0.35;
	// Tangent-space normal: block pores plus the joint slope.
	vec3 n = vec3(-g.x * slope * 0.9 + (gr - 0.5) * 0.25, -g.y * slope * 0.9 + (fine - 0.5) * 0.25, 1.0);
	NORMAL_MAP = normalize(n) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
}
