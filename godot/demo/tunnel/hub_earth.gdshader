// A junction's hub (bore_view.gd HUBS): a lathe of the bores' horseshoe round the junction, its floor a
// disc. Decision 0208 (the underground revamp's P2). Its surface is bore_surface.gdshaderinc's; here only
// the cuts: nothing above the section plane, and no wall where a bore opens into it -- CUSTOM0 the hub's
// centre and crown (x, z, floor radius, crown), CUSTOM1 the angles its bores leave at (x, z: cos, sin),
// CUSTOM2 their floor half-widths (0: none), CUSTOM3 their crowns. UV2.y is 1 on the wall, 0 on the floor.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://demo/tunnel/bore_surface.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 hub;
varying vec4 angles;
varying vec4 halves;
varying vec4 crowns;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	hub = CUSTOM0;
	angles = CUSTOM1;
	halves = CUSTOM2;
	crowns = CUSTOM3;
}

bool opening(vec3 p) {
	return in_opening(hub.xy, angles.x, halves.x, crowns.x, p) || in_opening(hub.xy, angles.y, halves.y, crowns.y, p)
		|| in_opening(hub.xy, angles.z, halves.z, crowns.z, p) || in_opening(hub.xy, angles.w, halves.w, crowns.w, p);
}

void fragment() {
	if (world_pos.y > cut_y || (UV2.y > 0.5 && opening(world_pos))) {
		discard;
	}
	vec3 albedo;
	float rough;
	vec3 emission;
	bore_shade(world_pos, normalize(world_normal), UV, UV2, COLOR, albedo, rough, emission);
	ALBEDO = albedo;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	EMISSION = emission;
}
