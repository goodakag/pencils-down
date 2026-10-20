shader_type spatial;
// Mineral-fibre ceiling tile: off-white with fissures and pinholes.

uniform vec3 base : source_color = vec3(0.93, 0.925, 0.9);
uniform sampler2D grain : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz;
	float a = texture(grain, uv * 2.2).r;
	float b = texture(grain, uv * 6.5 + 0.3).g;
	float fissure = smoothstep(0.38, 0.3, a) * 0.35 + smoothstep(0.3, 0.22, b) * 0.4;
	ALBEDO = base * (1.0 - fissure * 0.45);
	ROUGHNESS = 0.97;
	NORMAL_MAP = normalize(vec3((a - 0.5) * 0.4, (b - 0.5) * 0.4, 1.0)) * 0.5 + 0.5;
}
