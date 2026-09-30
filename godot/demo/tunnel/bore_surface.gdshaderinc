// The swept bores' and junction hubs' shared surface (bore_earth.gdshader, hub_earth.gdshader). Decisions
// 0207 (P1: the earth, the drying hook, the cutaway) and 0208 (P2: where bores meet at a hub). The cap's
// earth (underground_earth.gdshaderinc) in world space, triplanar-grained, with:
//   * THE FLOOR packed hard and a shade paler down its worn middle (UV: the profile coordinate);
//   * STONES bedded in the walls (a cellular noise, triplanar), and ROOTS streaking the walls under trees;
//   * DAMP: dug on game day UV2.x, dark and glossy, paling to dry earth over `dry_days`;
//   * its state from COLOR: flooded (R) a wet blue-grey, a fall (G) dark rubble;
//   * a faint emission floor, so an unlit bore reads as dark earth, never black;
//   * THE CUTAWAY: nothing above the section plane (`cut_y`) is drawn;
//   * a room's STONE LINING (COLOR.b, decision 0209: a root cellar's walls and floor): cool grey-blue blocks
//     in world space, courses on the walls and flags on the floor.
// THE JOIN (P2): a hub is a lathe of the bores' own horseshoe round its junction (bore_view.gd HUBS). A bore
// drops what lies inside a hub it ends at (`in_hub`), and a hub drops the wall where a bore opens into it
// (`in_opening`) -- one shape test on each side of one surface, so the two meet with no seam and no gap.
// A ROOM (P3, decision 0209) cuts a bore that joins it at a socket or its door with a PLANE through the wall
// there (a hub with a negative radius: x, z the socket, w the angle into the room): its walls bow out past the
// floor, and a plane at the floor's edge meets the room's opening, whose sides are the bore's own profile.

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
uniform vec3 lining_colour : source_color = vec3(0.45, 0.49, 0.53);
uniform vec3 mortar_colour : source_color = vec3(0.24, 0.25, 0.26);
// The level's floor (hubs stand on it) and the horseshoe's shape (bore_mesh.gd BULGE, SPRING_SHARE).
uniform float level_floor_y = -1.25;
uniform float bulge = 1.1;
uniform float spring_share = 0.45;

// bore_mesh.gd width_share: the horseshoe's half-width at t crowns up, in floor half-widths (-1 outside).
float horseshoe_share(float t) {
	if (t < 0.0 || t > 1.0) {
		return -1.0;
	}
	if (t <= spring_share) {
		return 1.0 + (bulge - 1.0) * sin(1.5707963 * t / spring_share);
	}
	float up = (t - spring_share) / (1.0 - spring_share);
	return bulge * sqrt(max(1.0 - up * up, 0.0));
}

// A bore's floor lies within this of the level's floor (bore_mesh.gd FLOOR_JITTER_M, with room to spare).
const float FLOOR_SLACK_M = 0.02;

// Whether world point p lies inside hub = (x, z, floor radius, crown) (a radius of 0: no hub). A point of a
// bore's floor jittered a few millimetres BELOW the level's floor counts as on it -- otherwise those patches
// of the bore's floor would stay drawn through the hub's floor, showing as triangles of another shade.
bool in_hub(vec4 hub, vec3 p) {
	if (hub.z < 0.0) {
		return dot(p.xz - hub.xy, vec2(cos(hub.w), sin(hub.w))) > 0.0;
	}
	if (hub.z == 0.0) {
		return false;
	}
	float up = p.y - level_floor_y;
	if (up < 0.0 && up > -FLOOR_SLACK_M) {
		up = 0.0;
	}
	float share = horseshoe_share(up / max(hub.w, 0.01));
	return share > 0.0 && distance(p.xz, hub.xy) < hub.z * share;
}

// Whether world point p lies inside a bore leaving centre c at `angle` (x, z: cos, sin), of floor half-width
// `half` and crown `crown` (a half-width of 0: no bore).
bool in_opening(vec2 c, float angle, float half, float crown, vec3 p) {
	if (half <= 0.0) {
		return false;
	}
	vec2 dir = vec2(cos(angle), sin(angle));
	vec2 d = p.xz - c;
	float share = horseshoe_share((p.y - level_floor_y) / max(crown, 0.01));
	return dot(d, dir) > 0.0 && share > 0.0 && abs(dot(d, vec2(-dir.y, dir.x))) < half * share;
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

// A stone lining at a fragment (see the header): courses of blocks along a wall (a room's walls stand on the
// world's axes or round it), flags on a floor, each block's shade from the grain, the mortar dark.
vec3 stone_lining(vec3 p, float wall, float grain_value) {
	vec2 q = wall > 0.5 ? vec2(p.x + p.z, p.y) : p.xz;
	vec2 size = wall > 0.5 ? vec2(0.46, 0.27) : vec2(0.62, 0.48);
	float row = floor(q.y / size.y);
	vec2 cell = fract(vec2(q.x / size.x + 0.5 * mod(row, 2.0), q.y / size.y));
	float mortar = 1.0 - step(0.06, cell.x) * step(0.08, cell.y);
	return mix(lining_colour * mix(0.78, 1.1, grain_value), mortar_colour, mortar);
}

// The surface's colour, roughness and emission at a fragment (see the header).
void bore_shade(vec3 p, vec3 n, vec2 uv, vec2 uv2, vec4 state, out vec3 albedo, out float rough, out vec3 emission) {
	float grain_value = triplanar(grain, p, n, grain_scale);
	vec3 earth = earth_strata(earth_ground(p.xz), p.xz, p.y);
	earth *= mix(0.78, 1.12, grain_value);
	float wall = 1.0 - step(0.8, n.y);
	earth = earth_roots(earth, p.xz, wall * smoothstep(0.35, 0.8, triplanar(grain, p * vec3(3.0, 0.4, 3.0), n, 1.0)));
	float stone = 1.0 - smoothstep(0.1, 0.18, triplanar(cells, p, n, stone_scale));
	earth = mix(earth, stone_colour * mix(0.8, 1.1, grain_value), stone * wall);
	vec3 colour = n.y > 0.8 ? floor_colour(earth, uv.x, grain_value) : earth;
	float dry = clamp((now_days - uv2.x) / dry_days, 0.0, 1.0);
	colour *= mix(0.58, 1.0, dry);
	rough = mix(0.62, 0.96, dry);
	colour = mix(colour, stone_lining(p, wall, grain_value), state.b);
	rough = mix(rough, 0.82, state.b);
	colour = mix(colour, water_colour, state.r * 0.7);
	colour = mix(colour, rubble_colour * mix(0.7, 1.3, grain_value), state.g);
	rough = mix(mix(rough, 0.3, state.r), 0.85, stone * wall);
	albedo = colour;
	emission = colour * emission_floor;
}
