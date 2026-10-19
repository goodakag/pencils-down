shader_type canvas_item;
// Soft background blur for menus (mip sampling of the screen) with a warm paper wash.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 3.2;
uniform vec4 wash : source_color = vec4(0.97, 0.95, 0.9, 0.18);

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	c = mix(c, wash.rgb, wash.a);
	COLOR = vec4(c, 1.0);
}
