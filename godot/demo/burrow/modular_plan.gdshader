shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;

// Preview only. The triangles clip the fill; the grid never changes the room geometry.
uniform vec4 tint : source_color = vec4(0.87, 0.82, 0.69, 1.0);
uniform vec2 datum_m = vec2(0.0);
uniform float pitch_m = 1.0;
uniform float fill_alpha = 0.12;
uniform float line_alpha = 0.24;
varying vec2 ground_m;

void vertex() {
	ground_m = VERTEX.xz - datum_m;
}

void fragment() {
	vec2 cell = ground_m / pitch_m;
	vec2 edge = abs(fract(cell - 0.5) - 0.5) / max(fwidth(cell), vec2(0.001));
	float line = 1.0 - clamp(min(edge.x, edge.y), 0.0, 1.0);
	ALBEDO = tint.rgb;
	ALPHA = fill_alpha + line * line_alpha;
}
