// The underground view's section cap. Decisions 0206 and 0207 (underground_cap.gd has the whole story).
// Drawn at the crown of the level (the section plane), but everything it SHOWS is read where the view ray
// meets the level's FLOOR -- the strata at the floor's own height too -- so the ground types, the no-dig
// band and the marks lie under the floor point a click there lands on (demo_layers.gd pick_y).
// THE VOID (P1): each fragment walks its view ray down from the cap to the floor, VOID_STEPS points, and
// asks at each whether the point lies inside a dug bore -- its horseshoe at that height, over that
// point's own floor (a ramp's is higher). If any does, the ray enters the bore there: the cap is cut away
// and the bore's far wall or floor (bore_mesh.gd, inward-facing) is seen through it. Where the ray only
// grazes a bore, a dark cut band edges the section. A dug room (P0's, still flat) opens where its floor
// point is dug.
// THE OTHER LEVEL (decision 0212): each level has its own cap and mask; `other_void` is the other level's mask,
// read at this level's floor point, and its bores' floor edges and rooms' edges are drawn as a faint line
// (`other_strength`) -- an outline only, nothing of it is seen through.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

#include "res://demo/tunnel/underground_earth.gdshaderinc"

// R: a dug room's floor (> 0.5). G: 1 - rho / 2, rho a point's distance from the nearest bore disc over
// that disc's floor half-width (G > 0.5 inside a bore's floor). B: that disc's floor rise over the level's
// floor / rise_range. A: its crown / crown_range. VOID_PX_PER_M.
uniform sampler2D void_map : filter_linear, repeat_disable;
uniform float floor_y = -1.25;
uniform float rise_range = 1.25;
uniform float crown_range = 2.0;
uniform float bulge = 1.1;
uniform float spring_share = 0.45;
uniform float band_rho = 0.16;
uniform float water_line = 0.5625;
uniform float cut_edge = 0.2;
uniform float footing_range_m = 1.0;
uniform float footing_line_m = 0.07;
uniform float hatch_period_m = 0.7;
uniform vec3 band_light : source_color = vec3(0.36, 0.47, 0.58);
uniform vec3 band_dark : source_color = vec3(0.22, 0.31, 0.42);
uniform vec3 water_colour : source_color = vec3(0.16, 0.25, 0.36);
uniform vec3 footing_colour : source_color = vec3(0.56, 0.54, 0.50);
uniform vec3 cut_colour : source_color = vec3(0.06, 0.045, 0.035);
uniform sampler2D other_void : filter_linear, repeat_disable, hint_default_black;
uniform float other_strength = 0.0;
uniform float other_line_rho = 0.14;
uniform vec3 other_colour : source_color = vec3(0.86, 0.8, 0.66);

const int VOID_STEPS = 10;

vec2 floor_point(vec3 eye, vec3 seen) {
	float reach = (eye.y - floor_y) / max(eye.y - seen.y, 0.0001);
	return eye.xz + (seen.xz - eye.xz) * reach;
}

// bore_mesh.gd width_share: the horseshoe's half-width at t crowns up, in floor half-widths.
float width_share(float t) {
	if (t < 0.0 || t > 1.0) {
		return -1.0;
	}
	if (t <= spring_share) {
		return 1.0 + (bulge - 1.0) * sin(1.5707963 * t / spring_share);
	}
	float up = (t - spring_share) / (1.0 - spring_share);
	return bulge * sqrt(max(1.0 - up * up, 0.0));
}

// How far outside the bores a point at height y over (x, z) lies, in floor half-widths (< 0: inside).
float void_margin(vec2 at, float y) {
	vec4 v = texture(void_map, earth_uv(at));
	float rho = (1.0 - v.g) * 2.0;
	float crown = max(v.a * crown_range, 0.01);
	return rho - width_share((y - floor_y - v.b * rise_range) / crown);
}

float ray_margin(vec3 eye, vec3 seen) {
	float margin = 4.0;
	float cap_y = seen.y;
	for (int i = 0; i < VOID_STEPS; i++) {
		float y = mix(cap_y, floor_y, float(i) / float(VOID_STEPS - 1));
		float reach = (eye.y - y) / max(eye.y - cap_y, 0.0001);
		margin = min(margin, void_margin(eye.xz + (seen.xz - eye.xz) * reach, y));
	}
	return margin;
}

// THE OTHER LEVEL: how strongly the other level's outline shows at `at` (0..1): the rim of its bores' floors,
// and its rooms' edges.
float other_line(vec2 at) {
	vec4 o = texture(other_void, earth_uv(at));
	float rho = (1.0 - o.g) * 2.0;
	float rim = o.g > 0.0 ? 1.0 - smoothstep(0.0, other_line_rho, abs(rho - 1.0)) : 0.0;
	float room_edge = 1.0 - smoothstep(0.0, 0.3, abs(o.r - 0.5));
	return max(rim, room_edge);
}

vec3 no_dig(vec3 earth, vec2 at, float water) {
	float stripe = step(0.5, fract((at.x + at.y) / hatch_period_m));
	vec3 band = mix(band_light, band_dark, stripe);
	return water > water_line ? mix(water_colour, band_dark, 0.55 * stripe) : mix(earth, band, 0.75);
}

void fragment() {
	vec3 seen = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 at = floor_point(CAMERA_POSITION_WORLD, seen);
	float room = texture(void_map, earth_uv(at)).r;
	float margin = ray_margin(CAMERA_POSITION_WORLD, seen);
	if (room > 0.5 || margin < 0.0) {
		discard;
	}
	vec4 marks = texture(marks_map, earth_uv(at));
	vec3 earth = earth_strata(earth_ground(at), at, floor_y) * mix(0.8, 1.15, texture(grain, at * grain_per_m).r);
	earth = earth_roots(earth, at, 1.0);
	float footing = (marks.r - 0.5) * 2.0 * footing_range_m;
	float outline = 1.0 - smoothstep(footing_line_m, footing_line_m + 0.05, abs(footing));
	earth = mix(earth, footing_colour, max(outline, step(0.0, footing) * 0.22));
	float water = texture(ground_map, earth_uv(at)).a;
	earth = water > 0.5 ? no_dig(earth, at, water) : earth;
	earth = mix(earth, other_colour, other_strength * other_line(at));
	ALBEDO = (room > cut_edge || margin < band_rho) ? cut_colour : earth;
	ROUGHNESS = 1.0;
}
