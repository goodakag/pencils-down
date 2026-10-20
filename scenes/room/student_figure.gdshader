shader_type spatial;
// A classmate: the CC0 base body's skin, with clothes painted on from a per-vertex mask built by
// StudentFigure (COLOR.r = torso, COLOR.g = legs, COLOR.b = feet, COLOR.a = distance out along
// the arm, 0 off the arm). Clothed areas are pushed out a little so they read as fabric.

uniform sampler2D skin_tex : source_color, filter_linear_mipmap;
uniform sampler2D skin_rough : hint_default_white, filter_linear_mipmap;
uniform vec3 skin_tint : source_color = vec3(1.0);
uniform vec3 shirt : source_color = vec3(0.3, 0.35, 0.45);
uniform vec3 pants : source_color = vec3(0.2, 0.27, 0.4);
uniform vec3 shoes : source_color = vec3(0.92, 0.92, 0.9);
uniform sampler2D shirt_fabric : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D pants_fabric : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float sleeve = 0.62;   // how far down the arm the sleeve reaches (0.3 short, 0.95 long)

varying float v_shirt;
varying float v_pants;
varying float v_shoes;

void vertex() {
	float arm = COLOR.a;
	v_shirt = max(COLOR.r, (arm > 0.001 && arm < sleeve) ? 1.0 : 0.0);
	v_pants = COLOR.g;
	v_shoes = COLOR.b;
	VERTEX += NORMAL * (v_shirt * 0.009 + v_pants * 0.005 + v_shoes * 0.006);
}

void fragment() {
	vec3 skin = texture(skin_tex, UV).rgb * skin_tint;
	float fs = dot(texture(shirt_fabric, UV * 9.0).rgb, vec3(0.333));
	float fp = dot(texture(pants_fabric, UV * 7.0).rgb, vec3(0.333));
	vec3 cloth_s = shirt * (0.8 + fs * 0.4);
	vec3 cloth_p = pants * (0.75 + fp * 0.5);
	vec3 col = skin;
	col = mix(col, cloth_s, v_shirt);
	col = mix(col, cloth_p, v_pants * (1.0 - v_shirt));
	col = mix(col, shoes, v_shoes);
	ALBEDO = col;
	float skin_r = texture(skin_rough, UV).g;
	float cloth = clamp(v_shirt + v_pants + v_shoes, 0.0, 1.0);
	ROUGHNESS = mix(skin_r, 0.93, cloth);
	SPECULAR = mix(0.45, 0.2, cloth);
}
