// Demo woodland ground: grass / moss / earth driven by noise, worn dirt paths from capsules,
// and leaf litter beyond the clearing. Decision 0196 (live demo). Presentation only.
//
// Everything is sampled in world XZ, so the ground plane can be any size without stretching.
// Paths are capsules (segment + radius) passed from world_layout.gd, the same ones the scatter
// uses to keep ground cover off them; the ragged edge comes from the same noise as the grass.
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

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
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

	float ragged = (mid - 0.5) * 0.9 + (fine - 0.5) * 0.5;
	float d = path_distance(world_xz) + ragged;
	float path = 1.0 - smoothstep(-0.35, 0.25, d);
	float verge = 1.0 - smoothstep(0.0, 1.1, d);
	grass = mix(grass, earth_color, verge * 0.3);
	// Packed earth: darker and damper at the edges and in broad patches, never speckled.
	float wear = smoothstep(0.3, 0.85, mid) * 0.42 + (1.0 - smoothstep(-1.2, 0.0, d)) * 0.35;
	vec3 dirt = mix(path_color, path_worn_color, clamp(wear, 0.0, 1.0));
	dirt *= mix(0.94, 1.04, fine) * mix(0.97, 1.02, detail);

	ALBEDO = mix(grass, dirt, path);
	ROUGHNESS = mix(0.93, 0.88, path);
	SPECULAR = 0.3;
	NORMAL_MAP = texture(detail_normal, world_xz * 0.33).rgb;
	NORMAL_MAP_DEPTH = mix(0.55, 1.0, path);
}
