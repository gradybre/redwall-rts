shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;

// World-anchored presentation grid; the mesh itself clips it to the room boundary.
uniform vec4 tint : source_color = vec4(0.87, 0.82, 0.69, 1.0);
uniform float grid_m = 0.25;
varying vec2 ground_m;

void vertex() {
	ground_m = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 cell = ground_m / grid_m;
	vec2 edge = abs(fract(cell - 0.5) - 0.5) / max(fwidth(cell), vec2(0.001));
	float line = 1.0 - clamp(min(edge.x, edge.y), 0.0, 1.0);
	ALBEDO = tint.rgb;
	ALPHA = 0.08 + line * 0.26;
}
