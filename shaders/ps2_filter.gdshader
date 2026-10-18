shader_type canvas_item;
// The optional PS2 screen filter (ScreenFilter mode "ps2", owner's direction of 16 Oct: a slow move toward a PS2 look).
// Three small things the console's picture had: a slightly soft image, a little bloom on the bright parts, and colour
// banding hidden by an ordered dither. The banding is the classic 4x4 Bayer pattern (a public matrix); written here from
// scratch, not taken from an emulator or another project.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform int bits : hint_range(2, 8) = 6;  // bits per colour channel kept: 8 is no banding
uniform float dither_strength : hint_range(0.0, 1.0) = 1.0;
uniform float blur : hint_range(0.0, 2.0) = 0.6;  // softness, in pixels
uniform float bloom : hint_range(0.0, 1.0) = 0.18;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.72;

const int BAYER[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

float bayer4(ivec2 p) {
	return (float(BAYER[(p.y & 3) * 4 + (p.x & 3)]) + 0.5) / 16.0 - 0.5;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur;
	vec3 c = texture(screen_tex, SCREEN_UV).rgb * 0.4;
	c += texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0)).rgb * 0.15;
	c += texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0)).rgb * 0.15;
	c += texture(screen_tex, SCREEN_UV + vec2(0.0, px.y)).rgb * 0.15;
	c += texture(screen_tex, SCREEN_UV - vec2(0.0, px.y)).rgb * 0.15;
	// bloom: the part of the soft image above the threshold, spread a little wider and added back
	vec3 wide = texture(screen_tex, SCREEN_UV + vec2(px.x, px.y) * 3.0).rgb
		+ texture(screen_tex, SCREEN_UV - vec2(px.x, px.y) * 3.0).rgb
		+ texture(screen_tex, SCREEN_UV + vec2(px.x, -px.y) * 3.0).rgb
		+ texture(screen_tex, SCREEN_UV + vec2(-px.x, px.y) * 3.0).rgb;
	c += max(wide * 0.25 - vec3(bloom_threshold), vec3(0.0)) * bloom * 3.0;
	// colour depth and dither
	float levels = float((1 << bits) - 1);
	float d = bayer4(ivec2(FRAGCOORD.xy)) * dither_strength;
	c = floor(clamp(c, 0.0, 1.0) * levels + 0.5 + d) / levels;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
