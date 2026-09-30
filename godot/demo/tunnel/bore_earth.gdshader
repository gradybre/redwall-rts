// A swept bore's walls and floor (bore_mesh.gd). Decisions 0207 (the underground revamp's P1) and 0208 (P2:
// the hubs). Its surface is bore_surface.gdshaderinc's; here only the cuts: nothing above the section plane,
// and nothing inside the hub of a junction it ends at -- CUSTOM0 its node A's hub, CUSTOM1 its node B's
// (x, z, floor radius, crown; a radius of 0: no hub there), constant over the segment's mesh.
// Back faces are culled: the mesh faces inward, so from above only the floor and the far wall are drawn.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://demo/tunnel/bore_surface.gdshaderinc"

varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 hub_a;
varying vec4 hub_b;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	hub_a = CUSTOM0;
	hub_b = CUSTOM1;
}

void fragment() {
	if (world_pos.y > cut_y || in_hub(hub_a, world_pos) || in_hub(hub_b, world_pos)) {
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
