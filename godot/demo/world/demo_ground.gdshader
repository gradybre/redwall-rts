// Demo woodland ground: grass / moss / earth driven by noise, worn dirt paths from capsules,
// and leaf litter beyond the clearing. Decision 0196 (live demo). Presentation only.
//
// Everything is sampled in world XZ, so the ground plane can be any size without stretching.
// Paths are capsules (segment + radius) passed from world_layout.gd, the same ones the scatter
// uses to keep ground cover off them; the ragged edge comes from the same noise as the grass.
//
// FROST AND SNOW (decision 0301, review F42): weather_view.gd sets `snow_cover` (how much lies) and
// `frost_cover` (how much of it is frost). It lies on the ground itself, in world space -- so it has no
// edge anywhere -- on what faces up, thinner on the worn paths (trodden), and never at or below the water
// line (`water_level_y`): the carved bank's wet foot and the bed under the water stay as they are.
//
// FALLEN LEAVES (decision 0551, demo/seasons/season_view.gd): `leaf_fall` (0..1) lays drifts of fallen leaves in
// `leaf_fall_color` over the grass and the woods' litter through autumn and into winter -- thickest toward the
// woods, in drifts at the scale of a few leaves, fewest on the worn paths (trodden) and under any snow. The
// season view also moves `grass_color`, `grass_sun_color` and `litter_color` with the season.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D macro_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;

uniform vec3 grass_color : source_color;
uniform vec3 grass_sun_color : source_color;
uniform vec3 moss_color : source_color;
uniform vec3 earth_color : source_color;
uniform vec3 path_color : source_color;
uniform vec3 path_worn_color : source_color;
uniform vec3 litter_color : source_color;

uniform vec4 path_segments[24];
uniform float path_radii[24];
uniform int path_count = 0;
uniform float clearing_radius = 23.0;
uniform float clearing_wobble = 2.5;
uniform float south_opening = 15.0;
uniform float forest_blend = 9.0;
uniform float leaf_fall = 0.0;
uniform vec3 leaf_fall_color : source_color = vec3(0.55, 0.32, 0.13);

#include "res://demo/weather/cover.gdshaderinc"

varying vec2 world_xz;
varying float world_y;
varying float world_up;

void vertex() {
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world_xz = world.xz;
	world_y = world.y;
	world_up = cover_up(MODEL_NORMAL_MATRIX, NORMAL);
}

// How much frost or snow lies here, 0..1 (see FROST AND SNOW): `path` is the worn-path share.
float lying(float path, float fine, float mid) {
	float dry = cover_dry(world_y);
	float flat_ = smoothstep(0.6, 0.92, world_up);
	float patchy = smoothstep(0.25, 0.7, fine * 0.55 + mid * 0.55 + snow_cover * 0.35 - frost_cover * 0.2);
	float amount = snow_cover * dry * flat_ * mix(1.0, 0.45, path);
	return clamp(amount * mix(patchy, 1.0, (1.0 - frost_cover) * 0.6), 0.0, 1.0);
}

// Fallen leaves over `ground` (see FALLEN LEAVES): drifts from the mid noise, broken at leaf scale.
vec3 fallen_leaves(vec3 ground, float forest, float fine, float detail) {
	float speck = texture(detail_noise, world_xz * 3.1 + vec2(0.41, 0.83)).r;
	float drift = fine * 0.5 + detail * 0.3 + forest * 0.45 + leaf_fall * 0.25;
	float lying_leaves = smoothstep(0.6, 0.88, drift) * smoothstep(0.35, 0.65, speck + leaf_fall * 0.2);
	vec3 leaves = leaf_fall_color * mix(0.8, 1.15, speck);
	return mix(ground, leaves, clamp(lying_leaves * leaf_fall * 1.3, 0.0, 0.8));
}

float segment_distance(vec2 p, vec4 seg) {
	vec2 a = seg.xy;
	vec2 ab = seg.zw - a;
	float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
	return length(p - a - ab * h);
}

float path_distance(vec2 p) {
	float d = 100000.0;
	for (int i = 0; i < 24; i++) {
		if (i >= path_count) {
			break;
		}
		d = min(d, segment_distance(p, path_segments[i]) - path_radii[i]);
	}
	return d;
}

// Must match world_scatter.gd's clearing_edge(), which keeps trees out of the same clearing.
float clearing_edge(vec2 p) {
	float angle = atan(p.y, p.x);
	float wobble = sin(angle * 3.0 + 0.8) * 0.6 + sin(angle * 7.0 + 2.1) * 0.4;
	float south = max(0.0, sin(angle));
	return clearing_radius + wobble * clearing_wobble + south_opening * south * south;
}

void fragment() {
	float macro = texture(macro_noise, world_xz * 0.021).r;
	float mid = texture(macro_noise, world_xz * 0.093 + vec2(0.37, 0.71)).r;
	float fine = texture(detail_noise, world_xz * 0.23).r;
	float detail = texture(detail_noise, world_xz * 0.9 + vec2(0.13, 0.57)).r;

	vec3 grass = mix(grass_color, grass_sun_color, smoothstep(0.3, 0.75, macro));
	grass = mix(grass, moss_color, smoothstep(0.55, 0.8, mid) * 0.45);
	grass *= mix(0.9, 1.06, fine) * mix(0.96, 1.03, detail);
	float bare = smoothstep(0.7, 0.86, mid * 0.6 + fine * 0.5);
	grass = mix(grass, earth_color, bare * 0.4);

	float r = length(world_xz) + (macro - 0.5) * 10.0;
	float forest = smoothstep(clearing_edge(world_xz) - 3.0, clearing_edge(world_xz) + forest_blend, r);
	grass = mix(grass, litter_color * mix(0.88, 1.08, fine), forest * 0.8);
	if (leaf_fall > 0.0) {
		grass = fallen_leaves(grass, forest, fine, detail);
	}

	float ragged = (mid - 0.5) * 0.9 + (fine - 0.5) * 0.5;
	float d = path_distance(world_xz) + ragged;
	float path = 1.0 - smoothstep(-0.35, 0.25, d);
	float verge = 1.0 - smoothstep(0.0, 1.1, d);
	grass = mix(grass, earth_color, verge * 0.3);
	// Packed earth: darker and damper at the edges and in broad patches, never speckled.
	float wear = smoothstep(0.3, 0.85, mid) * 0.42 + (1.0 - smoothstep(-1.2, 0.0, d)) * 0.35;
	vec3 dirt = mix(path_color, path_worn_color, clamp(wear, 0.0, 1.0));
	dirt *= mix(0.94, 1.04, fine) * mix(0.97, 1.02, detail);

	float cover = lying(path, fine, mid);
	ALBEDO = cover_albedo(mix(grass, dirt, path), cover);
	ROUGHNESS = cover_roughness(mix(0.93, 0.88, path), cover);
	SPECULAR = 0.3;
	NORMAL_MAP = texture(detail_normal, world_xz * 0.33).rgb;
	NORMAL_MAP_DEPTH = mix(mix(0.55, 1.0, path), 0.25, cover * (1.0 - frost_cover));
}
