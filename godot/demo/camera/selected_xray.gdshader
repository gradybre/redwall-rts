// A selected resident seen through what stands in front of it: canopy, roofs, walls. Decision 0301
// (review F53). Presentation only; drawn as the resident's own material_overlay (canopy_clear.gd).
//
// Drawn over everything (no depth test), but only where the scene's own depth -- what the opaque pass
// put nearest the camera at this pixel -- lies more than `gap_m` in front of the resident's surface:
// where the resident is itself the nearest thing, or only a grass tuft at its feet covers it, the overlay
// discards and the resident shows as it is. So a selected mouse under an oak's crown or behind the hall
// is a brass silhouette, brighter at its rim, and the same mouse in the open is untouched. Both depths
// are compared as view distances in metres (the depth buffer is reversed and not linear).
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_back, blend_mix, shadows_disabled;

uniform sampler2D scene_depth : hint_depth_texture, filter_nearest;
uniform vec4 colour : source_color = vec4(0.706, 0.604, 0.345, 0.85);
// How much nearer (m) a surface must be to count as in front of the resident: grass at its feet is not.
uniform float gap_m = 0.6;

void fragment() {
	float nearest = texture(scene_depth, SCREEN_UV).r;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, nearest, 1.0);
	float scene_m = -scene.z / scene.w;
	if (-VERTEX.z - scene_m < gap_m) {
		discard;
	}
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = colour.rgb;
	ALPHA = colour.a * mix(0.5, 1.0, rim);
}
