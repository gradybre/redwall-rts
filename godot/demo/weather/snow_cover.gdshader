// Frost and snow lying on roofs and props. Decision 0301 (review F42). Presentation only; worn as each
// building's and prop's material_overlay while there is any (weather_view.gd).
//
// In world space: it lies on what faces up (a roof's slope, a barrel's lid, a boulder's top), patchy
// under frost, and never at or below the water line -- a diorama's own sunk base stays bare. Lit like
// the surface under it; drawn over that surface with the same depth, so it costs one blended pass on
// the meshes it is put on, and only while it lies.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform float snow_cover = 0.0;
uniform float frost_cover = 0.0;
uniform vec3 snow_color : source_color = vec3(0.93, 0.95, 0.98);
uniform float water_level_y = -0.18;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

varying vec3 world_pos;
varying float world_up;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	float up = smoothstep(0.35, 0.8, world_up);
	float dry = smoothstep(water_level_y + 0.04, water_level_y + 0.16, world_pos.y);
	float n = texture(noise, world_pos.xz * 0.4).r;
	float patchy = smoothstep(0.3, 0.65, n + snow_cover * 0.3 - frost_cover * 0.15);
	float amount = snow_cover * up * dry * mix(patchy, 1.0, (1.0 - frost_cover) * 0.5);
	ALBEDO = snow_color;
	ROUGHNESS = mix(0.75, 0.5, frost_cover);
	ALPHA = clamp(amount * mix(0.95, 0.6, frost_cover), 0.0, 1.0);
}
