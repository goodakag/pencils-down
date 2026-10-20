shader_type spatial;
// Vinyl composition tile: 12" tiles with slight colour differences between tiles, speckled
// "through-pattern" chips, hairline seams and a waxed satin shine.

uniform vec3 base_a : source_color = vec3(0.80, 0.77, 0.70);
uniform vec3 base_b : source_color = vec3(0.74, 0.71, 0.64);
uniform vec3 accent : source_color = vec3(0.55, 0.60, 0.62);
uniform sampler2D grain : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tile = 0.3048;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 23758.5453); }

void fragment() {
	vec2 uv = wpos.xz;
	vec2 cell = floor(uv / tile);
	vec2 f = fract(uv / tile) * tile;
	float d = min(min(f.x, tile - f.x), min(f.y, tile - f.y));
	float seam = 1.0 - smoothstep(0.0, 0.0012, d);
	float h = hash(cell);
	vec3 col = mix(base_a, base_b, step(0.5, h));
	if (hash(cell + 7.0) > 0.93) col = accent;   // the odd replacement tile
	// Directional mottling, like real VCT chips, rotated per tile.
	vec2 r = (fract(h * 4.0) > 0.5) ? f.yx : f;
	float chip = texture(grain, r * 3.0 + cell * 0.37).r;
	float speck = texture(grain, uv * 9.0).g;
	col *= 0.9 + chip * 0.18;
	col = mix(col, col * 0.72, smoothstep(0.62, 0.75, speck) * 0.6);
	col = mix(col, vec3(0.95, 0.94, 0.9), smoothstep(0.7, 0.82, 1.0 - speck) * 0.4);
	ALBEDO = col * (1.0 - seam * 0.35);
	float wax = texture(grain, uv * 0.35).b;
	ROUGHNESS = 0.24 + wax * 0.22 + seam * 0.3;
	SPECULAR = 0.55;
}
