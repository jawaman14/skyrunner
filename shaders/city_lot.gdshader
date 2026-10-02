// A real building model (Kenney's City Kits) standing where one of the city's boxes was.
// The kit paints walls white and slate with light-blue windows from one colour map; this tints the walls
// with the box's pastel (instance COLOR rgb), lights the windows at night the way city.gdshader does,
// and gives each building the 1980s-coast deco: a trim band and a neon strip under the roofline.
// Instance CUSTOM: x = world y of the roof, y = how many metres of wall there are (for the neon strip).
shader_type spatial;
render_mode cull_back;
global uniform float rain_wet;

uniform sampler2D albedo_tex : source_color, filter_nearest, repeat_disable;
uniform float night = 0.0;
uniform float neon = 1.0;  // 0 turns the neon and the trim off

varying vec4 icol;
varying float roof_y;
varying float bhash;
varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	icol = COLOR;
	roof_y = INSTANCE_CUSTOM.x;
	bhash = hash(MODEL_MATRIX[3].xz * 0.013);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	float lum = dot(t, vec3(0.299, 0.587, 0.114));
	float sat = max(t.r, max(t.g, t.b)) - min(t.r, min(t.g, t.b));
	// windows: the kit's light blue (blue clearly over red)
	float window = step(0.1, t.b - t.r) * step(0.45, t.b);
	// walls: the light, unsaturated parts (white); the slate roofs and trims keep their own colour
	float wall = smoothstep(0.6, 0.85, lum) * (1.0 - smoothstep(0.08, 0.22, sat)) * (1.0 - window);
	// squaring the pastel deepens it (flamingo, mint, lilac...) without making it darker where it is cream
	vec3 tint = icol.rgb * icol.rgb * 1.15;
	vec3 col = mix(t, t * tint, wall);
	float up_from_roof = roof_y - wpos.y;
	float is_wall = 1.0 - step(0.5, abs(wnrm.y));
	// deco trim: a band along the roofline in white, turquoise or flamingo, on some of them a neon strip
	float h1 = fract(bhash * 7.13);
	float h2 = fract(bhash * 13.7);
	vec3 trim = h1 < 0.4 ? vec3(0.97, 0.96, 0.93) : (h1 < 0.7 ? vec3(0.3, 0.78, 0.8) : vec3(0.95, 0.42, 0.62));
	float band = is_wall * step(up_from_roof, 0.9) * step(0.0, up_from_roof) * (1.0 - window);
	col = mix(col, trim, band * neon * 0.85);
	float has_neon = step(0.6, h2) * neon * icol.a;
	float strip = is_wall * has_neon * step(1.0, up_from_roof) * step(up_from_roof, 1.35) * (1.0 - window);
	vec3 neon_col = h1 < 0.5 ? vec3(1.0, 0.2, 0.62) : vec3(0.2, 0.9, 1.0);
	col = mix(col, neon_col * 0.7, strip);
	// a share of the windows lit after dark, by floor and bay
	float lit = step(0.62, hash(floor(wpos.xz * 0.45) + floor(wpos.y / 3.1) * 7.0));
	ALBEDO = col * (1.0 - 0.18 * rain_wet);
	ROUGHNESS = mix(mix(0.85, 0.2, window), 0.2, rain_wet * 0.8);
	METALLIC = 0.0;
	EMISSION = window * lit * night * vec3(1.0, 0.78, 0.48) * 1.3 + strip * neon_col * (0.3 + 4.0 * night);
}
