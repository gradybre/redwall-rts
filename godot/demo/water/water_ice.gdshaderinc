// Winter ice on the demo's water. Art pass 3, decision 0971. Presentation only, and NOT WIRED IN: the water revamp
// (#54) switches it on -- water_iced.gdshader is water.gdshader with this one hook; it can take that shader, or fold
// the hook's few lines into water.gdshader itself. With `ice_cover` at 0 it changes nothing.
//
// INCLUDE IT after the water shader's varyings (world_xz, v_depth, v_shore, v_flow) and its `foam_noise` sampler,
// and call `water_ice` last in fragment() with the surface's own albedo, roughness, specular, alpha, normal map and
// its shore `edge` (water.gdshader's own variables).
//
// WHERE IT FREEZES. Ice grows out from the shallows over the deep as `ice_cover` rises (0 open water; 1 frozen
// over), so a pond skins at its margins first and closes last over its deepest water. Moving water resists it:
// faster than `ice_flow_open` m/s stays open and between `ice_flow_slush` and that it is half frozen -- so the stream
// keeps an open channel with shelf ice along its slow edges, which is what pond_ice.gd says of it ("the stream never
// freezes"). A slushy pale rim marks the freeze front.
//
// WHAT IT LOOKS LIKE, by `ice_thick` (0 thin .. 1 safe; pond_ice.gd's FROZEN_UM..SAFE_UM is the natural feed):
//   * thin ice is dark, glassy and see-through: the water's own colour still shows, the ripples are stilled;
//   * safe ice is milky blue-white and near opaque, crazed with fine white cells and a few long fractures (two
//     scales of a cell-edge noise in world space, so it has no seams between water bodies), with bubbles caught in it;
//   * `ice_snow` lies on it in drifts (the weather's snow cover: liquid water never whitens, ice does).
// The ripple normals are flattened under the ice; the flow phase runs on beneath, unseen.

uniform float ice_cover : hint_range(0.0, 1.0) = 0.0;
uniform float ice_thick : hint_range(0.0, 1.0) = 0.0;
uniform float ice_snow : hint_range(0.0, 1.0) = 0.0;
uniform float ice_flow_slush = 0.04;
uniform float ice_flow_open = 0.14;
uniform vec3 ice_thin_color : source_color = vec3(0.17, 0.25, 0.29);
uniform vec3 ice_safe_color : source_color = vec3(0.6, 0.74, 0.83);
uniform vec3 ice_crack_color : source_color = vec3(0.94, 0.97, 1.0);
uniform vec3 ice_snow_color : source_color = vec3(0.93, 0.95, 0.98);
uniform float ice_crack_scale = 0.85;

vec2 ice_hash(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Distance to the nearest cell edge (second-nearest less nearest feature point): 0 on an edge.
float ice_cells(vec2 p) {
	vec2 cell = floor(p);
	vec2 inside = fract(p);
	float nearest = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 to = offset + ice_hash(cell + offset) - inside;
			float d = dot(to, to);
			if (d < nearest) {
				second = nearest;
				nearest = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return sqrt(second) - sqrt(nearest);
}

// How frozen this point is (0..1): the freeze front by depth, held back by the flow.
float water_ice_mask(float depth01, float speed) {
	float reach = ice_cover * 1.15;
	float front = 1.0 - smoothstep(reach - 0.1, reach, depth01);
	float still = 1.0 - smoothstep(ice_flow_slush, ice_flow_open, speed);
	return clamp(front * still * smoothstep(0.0, 0.05, ice_cover), 0.0, 1.0);
}

void water_ice(inout vec3 albedo, inout float roughness, inout float specular, inout float alpha,
		inout vec3 normal_map, float edge) {
	float ice = water_ice_mask(v_depth, length(v_flow));
	if (ice <= 0.001) {
		return;
	}
	vec2 p = world_xz * ice_crack_scale;
	float fine = 1.0 - smoothstep(0.0, 0.04, ice_cells(p));
	float fracture = 1.0 - smoothstep(0.0, 0.012, ice_cells(p * 0.17 + vec2(7.1, 3.3)) + 0.02 * texture(foam_noise, world_xz * 0.6).r);
	float bubbles = smoothstep(0.8, 0.92, texture(foam_noise, world_xz * 1.9).r);
	vec3 body = mix(mix(ice_thin_color, albedo, 0.35), ice_safe_color, ice_thick);
	body = mix(body, ice_crack_color, clamp(fine * (0.05 + 0.3 * ice_thick) + fracture * (0.15 + 0.25 * ice_thick), 0.0, 1.0));
	body = mix(body, ice_crack_color, bubbles * 0.3 * (1.0 - ice_thick * 0.5));
	float drift = smoothstep(0.45, 0.7, texture(foam_noise, world_xz * 0.23).r + ice_snow * 0.25 - 0.1);
	float snow = clamp(ice_snow * (0.15 + 0.85 * drift), 0.0, 1.0);
	body = mix(body, ice_snow_color, snow);
	float rim = ice * (1.0 - ice) * 4.0;
	body = mix(body, ice_snow_color * 0.9, rim * 0.45);
	albedo = mix(albedo, body, ice);
	roughness = mix(roughness, mix(0.14, 0.45, max(ice_thick * 0.5, snow)), ice);
	specular = mix(specular, mix(0.3, 0.5, ice_thick), ice);
	alpha = mix(alpha, mix(0.8, 0.97, max(ice_thick, snow)) * edge, ice);
	normal_map = mix(normal_map, vec3(0.5, 0.5, 1.0), ice * 0.92);
}
