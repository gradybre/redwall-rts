// The underground view's section cap. Decision 0206 (underground_cap.gd has the whole story).
// Drawn at the cap's height, but everything it shows is read where the view ray meets the level's FLOOR:
// a fragment over a dug void is discarded (the bore's floor shows through, and no near lip hides a
// walker's feet), and the strata, the no-dig band and the marks lie exactly under the floor point a
// click there lands on (demo_layers.gd pick_y).
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// RGB: the ground type's colour, 1 px a metre, read through a soft warp; A: the water's signed distance
// (0.5 = the no-dig edge), read unwarped, so the band lies exactly where a bore is refused.
uniform sampler2D ground_map : source_color, filter_linear, repeat_disable;
// R: the footings' signed distance (0.5 at their outline, inside above); B: roots under a tree.
// MARKS_PX_PER_M.
uniform sampler2D marks_map : filter_linear, repeat_disable;
// R: dug (> 0.5), stamped as bores and rooms are dug. VOID_PX_PER_M.
uniform sampler2D void_map : filter_linear, repeat_disable;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
// x0, z0 of the mapped square and 1 / its side (m).
uniform vec3 map_rect = vec3(-40.0, -40.0, 0.0125);
uniform float floor_y = -1.25;
uniform float water_line = 0.5625;
uniform float cut_edge = 0.2;
uniform float footing_range_m = 1.0;
uniform float footing_line_m = 0.07;
uniform float hatch_period_m = 0.7;
uniform float grain_per_m = 0.35;
// The strata's 1 m cells are sampled through a soft noise warp, so a patch's edge wanders, not steps.
uniform float warp_per_m = 0.11;
uniform float warp_m = 1.6;
uniform vec3 band_light : source_color = vec3(0.36, 0.47, 0.58);
uniform vec3 band_dark : source_color = vec3(0.22, 0.31, 0.42);
uniform vec3 water_colour : source_color = vec3(0.16, 0.25, 0.36);
uniform vec3 footing_colour : source_color = vec3(0.56, 0.54, 0.50);
uniform vec3 root_colour : source_color = vec3(0.17, 0.11, 0.07);
uniform vec3 cut_colour : source_color = vec3(0.06, 0.045, 0.035);

vec2 floor_point(vec3 eye, vec3 seen) {
	float reach = (eye.y - floor_y) / max(eye.y - seen.y, 0.0001);
	return eye.xz + (seen.xz - eye.xz) * reach;
}

vec3 no_dig(vec3 earth, vec2 at, float water) {
	float stripe = step(0.5, fract((at.x + at.y) / hatch_period_m));
	vec3 band = mix(band_light, band_dark, stripe);
	return water > water_line ? mix(water_colour, band_dark, 0.55 * stripe) : mix(earth, band, 0.75);
}

void fragment() {
	vec3 seen = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 at = floor_point(CAMERA_POSITION_WORLD, seen);
	vec2 uv = (at - map_rect.xy) * map_rect.z;
	float dug = texture(void_map, uv).r;
	if (dug > 0.5) {
		discard;
	}
	vec2 warp = vec2(texture(grain, at * warp_per_m).r, texture(grain, at * warp_per_m + vec2(0.37, 0.71)).r) - 0.5;
	vec4 ground = texture(ground_map, uv + warp * warp_m * map_rect.z);
	vec4 marks = texture(marks_map, uv);
	vec3 earth = ground.rgb * mix(0.8, 1.15, texture(grain, at * grain_per_m).r);
	earth = mix(earth, root_colour, clamp(marks.b, 0.0, 1.0) * 0.8);
	float footing = (marks.r - 0.5) * 2.0 * footing_range_m;
	float outline = 1.0 - smoothstep(footing_line_m, footing_line_m + 0.05, abs(footing));
	earth = mix(earth, footing_colour, max(outline, step(0.0, footing) * 0.22));
	float water = texture(ground_map, uv).a;
	earth = water > 0.5 ? no_dig(earth, at, water) : earth;
	ALBEDO = dug > cut_edge ? cut_colour : earth;
	ROUGHNESS = 1.0;
}
