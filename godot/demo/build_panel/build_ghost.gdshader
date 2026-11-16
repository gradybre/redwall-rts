shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, shadows_disabled;

// The build panel's ghost fill (decision 1912): the planner's plan shader (modular_plan.gdshader: the 1 m grid at
// the world datum) with HATCHING for an impossible group -- diagonal bands 0.5 m apart, half of each drawn strong and
// half faint -- so "X" reads as a pattern as well as a colour. Preview only.
uniform vec4 tint : source_color = vec4(0.87, 0.82, 0.69, 1.0);
uniform vec2 datum_m = vec2(0.0);
uniform float pitch_m = 1.0;
uniform float fill_alpha = 0.12;
uniform float line_alpha = 0.24;
uniform float hatch = 0.0;
varying vec2 ground_m;

void vertex() {
	ground_m = VERTEX.xz - datum_m;
}

void fragment() {
	vec2 cell = ground_m / pitch_m;
	vec2 edge = abs(fract(cell - 0.5) - 0.5) / max(fwidth(cell), vec2(0.001));
	float line = 1.0 - clamp(min(edge.x, edge.y), 0.0, 1.0);
	float diagonal = (ground_m.x + ground_m.y) / 0.5;
	float soft = max(fwidth(diagonal), 0.001);
	float stripe = smoothstep(0.5 - soft, 0.5 + soft, fract(diagonal));
	float fill = mix(fill_alpha, mix(0.08, 0.62, stripe), hatch);
	ALBEDO = tint.rgb;
	ALPHA = fill + line * line_alpha;
}
