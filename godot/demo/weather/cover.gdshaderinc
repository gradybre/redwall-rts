// Frost and snow lying on a surface: the uniforms weather_view.gd sets and the shared rules. Decision
// 0301 (review F42). Included by demo_ground.gdshader, water_bank.gdshader and snow_cover.gdshader.
//
// `snow_cover`: how much lies, 0..1. `frost_cover`: how much of it is frost (thinner, patchier, a little
// glossier). Nothing lies at or below the water line (`water_level_y`, the resting surface).

uniform float snow_cover = 0.0;
uniform float frost_cover = 0.0;
uniform vec3 snow_color : source_color = vec3(0.93, 0.95, 0.98);
uniform float water_level_y = -0.18;

// 0 at or below the water line, 1 a little above it.
float cover_dry(float world_y) {
	return smoothstep(water_level_y + 0.04, water_level_y + 0.16, world_y);
}

// A surface's albedo under `cover` of frost or snow.
vec3 cover_albedo(vec3 albedo, float cover) {
	return mix(albedo, snow_color, cover * mix(0.92, 0.55, frost_cover));
}

// A surface's roughness under `cover` of frost or snow.
float cover_roughness(float roughness, float cover) {
	return mix(roughness, mix(0.78, 0.5, frost_cover), cover);
}

// A world-space normal's up component (the normal matrix keeps it right on a non-uniformly scaled mesh).
float cover_up(mat3 normal_matrix, vec3 normal) {
	return normalize(normal_matrix * normal).y;
}
