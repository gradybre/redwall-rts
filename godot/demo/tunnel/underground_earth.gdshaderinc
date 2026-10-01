// The underground's one earth, shared by the section cap (underground_cap.gdshader) and the swept bores'
// walls and floors (bore_earth.gdshader), so where a wall meets the cut they are the same soil.
// Decision 0207 (the underground revamp's P1; design docs/design/underground_revamp.md §6 "Materials").
//
// Earth is read in WORLD space: the ground map's colour at (x, z) -- loam, rust clay, pale sand, grey
// rock, blue-tinted wet ground, exactly where they slow or weaken a dig (tunnel_ground.gd) -- through a
// soft noise warp, banded by height (a darker humus under the turf, a clay seam lower down), with a
// grain. The cap reads it at the floor point under the pointer; a wall at its own point.

// RGB: the ground type's colour, 1 px a metre; A: the water's signed distance (the cap's no-dig band).
uniform sampler2D ground_map : source_color, filter_linear, repeat_disable;
// R: the footings' signed distance; B: root tangles under trees. MARKS_PX_PER_M.
uniform sampler2D marks_map : filter_linear, repeat_disable;
uniform sampler2D grain : filter_linear_mipmap, repeat_enable;
// x0, z0 of the mapped square and 1 / its side (m).
uniform vec3 map_rect = vec3(-40.0, -40.0, 0.0125);
uniform float grain_per_m = 0.35;
uniform float warp_per_m = 0.11;
uniform float warp_m = 1.6;
uniform vec3 humus_colour : source_color = vec3(0.19, 0.13, 0.085);
uniform vec3 seam_colour : source_color = vec3(0.47, 0.27, 0.17);
uniform vec3 root_colour : source_color = vec3(0.17, 0.11, 0.07);
// The humus runs from the turf down to humus_base_y; the clay seam wanders round seam_y.
uniform float humus_base_y = -0.45;
uniform float seam_y = -0.95;
uniform float seam_half_m = 0.07;

vec2 earth_uv(vec2 at) {
	return (at - map_rect.xy) * map_rect.z;
}

// The ground type's colour at (x, z), its edges wandering through the warp.
vec3 earth_ground(vec2 at) {
	vec2 warp = vec2(texture(grain, at * warp_per_m).r, texture(grain, at * warp_per_m + vec2(0.37, 0.71)).r) - 0.5;
	return texture(ground_map, earth_uv(at) + warp * warp_m * map_rect.z).rgb;
}

// Height bands over a ground colour: humus near the turf, a clay seam below, a little darker deeper.
vec3 earth_strata(vec3 ground, vec2 at, float y) {
	float wobble = (texture(grain, at * 0.21 + vec2(0.13, 0.57)).r - 0.5) * 0.3;
	float humus = smoothstep(humus_base_y - 0.12, humus_base_y + 0.08, y + wobble);
	vec3 earth = mix(ground, humus_colour, humus * 0.55);
	float seam = 1.0 - smoothstep(seam_half_m, seam_half_m + 0.05, abs(y - seam_y + wobble * 0.8));
	earth = mix(earth, seam_colour, seam * 0.45);
	return earth * mix(0.92, 1.0, clamp(y + 1.6, 0.0, 1.0));
}

// Root tangles under a tree (the cap's marks), streaked down a wall.
vec3 earth_roots(vec3 earth, vec2 at, float streak) {
	float roots = clamp(texture(marks_map, earth_uv(at)).b, 0.0, 1.0);
	return mix(earth, root_colour, roots * 0.8 * streak);
}
