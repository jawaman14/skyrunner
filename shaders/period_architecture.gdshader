shader_type spatial;
render_mode cull_disabled;
global uniform float rain_wet;
uniform float night = 0.0;
varying vec3 wpos;
varying vec3 pigment;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pigment = COLOR.rgb;
}
void fragment() {
	float grain = fract(sin(dot(floor(wpos.xz * 2.0 + wpos.y), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = pigment * (0.88 + grain * 0.12) * (1.0 - rain_wet * 0.12);
	ROUGHNESS = 0.92 - rain_wet * 0.2;
	METALLIC = 0.0;
	float window = step(pigment.r * 1.2, pigment.b) * step(0.23, pigment.b);
	EMISSION = window * night * vec3(0.7, 0.47, 0.20);
}
