// A swept bore's walls and floor (bore_mesh.gd). Decision 0207 (the underground revamp's P1; design
// docs/design/underground_revamp.md §6 "Materials"). The cap's earth (underground_earth.gdshaderinc) in
// world space, triplanar-grained, with:
//   * THE FLOOR packed hard and a shade paler down its worn middle (UV: the profile coordinate);
//   * STONES bedded in the walls (a cellular noise, triplanar), and ROOTS streaking the walls under trees;
//   * DAMP: a ring dug on game day UV2.x is dark and glossy, paling to dry earth over `dry_days`
//     (`now_days` is the demo calendar's day; P5 builds on the hook);
//   * its state from COLOR: flooded (R) a wet blue-grey, a fall (G) dark rubble;
//   * a faint emission floor, so an unlit bore reads as dark earth, never black;
//   * THE CUTAWAY: nothing above the section plane (`cut_y`) is drawn -- a mouth's ramp rises through it.
// Back faces are culled: the mesh faces inward, so from above only the floor and the far wall are drawn.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://demo/tunnel/underground_earth.gdshaderinc"

uniform sampler2D cells : filter_linear_mipmap, repeat_enable;
uniform float cut_y = -0.15;
uniform float now_days = 0.0;
uniform float dry_days = 1.0;
uniform float grain_scale = 1.1;
uniform float stone_scale = 0.9;
uniform vec3 packed_colour : source_color = vec3(0.36, 0.27, 0.19);
uniform vec3 path_colour : source_color = vec3(0.46, 0.36, 0.26);
uniform vec3 stone_colour : source_color = vec3(0.43, 0.41, 0.37);
uniform vec3 water_colour : source_color = vec3(0.17, 0.22, 0.25);
uniform vec3 rubble_colour : source_color = vec3(0.13, 0.1, 0.075);
uniform float emission_floor = 0.04;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(w.x + w.y + w.z, 0.0001);
	return texture(tex, p.zy * scale).r * w.x + texture(tex, p.xz * scale).r * w.y + texture(tex, p.xy * scale).r * w.z;
}

vec3 floor_colour(vec3 earth, float across, float grain_value) {
	float worn = 1.0 - smoothstep(0.25, 0.6, abs(across));
	vec3 packed = mix(earth, packed_colour, 0.55);
	return mix(packed, path_colour, worn * 0.6) * mix(0.9, 1.06, grain_value);
}

void fragment() {
	if (world_pos.y > cut_y) {
		discard;
	}
	vec3 n = normalize(world_normal);
	float grain_value = triplanar(grain, world_pos, n, grain_scale);
	vec3 earth = earth_strata(earth_ground(world_pos.xz), world_pos.xz, world_pos.y);
	earth *= mix(0.78, 1.12, grain_value);
	float wall = 1.0 - step(0.8, n.y);
	earth = earth_roots(earth, world_pos.xz, wall * smoothstep(0.35, 0.8, triplanar(grain, world_pos * vec3(3.0, 0.4, 3.0), n, 1.0)));
	float stone = 1.0 - smoothstep(0.1, 0.18, triplanar(cells, world_pos, n, stone_scale));
	earth = mix(earth, stone_colour * mix(0.8, 1.1, grain_value), stone * wall);
	vec3 colour = n.y > 0.8 ? floor_colour(earth, UV.x, grain_value) : earth;
	float dry = clamp((now_days - UV2.x) / dry_days, 0.0, 1.0);
	colour *= mix(0.58, 1.0, dry);
	float rough = mix(0.62, 0.96, dry);
	colour = mix(colour, water_colour, COLOR.r * 0.7);
	colour = mix(colour, rubble_colour * mix(0.7, 1.3, grain_value), COLOR.g);
	rough = mix(rough, 0.3, COLOR.r);
	ALBEDO = colour;
	ROUGHNESS = mix(rough, 0.85, stone * wall);
	SPECULAR = 0.35;
	EMISSION = colour * emission_floor;
}
