// A tree drawn with its crown thinned out of the camera's way. Decision 0301 (review F53). Presentation.
//
// The tree's own glTF material (albedo, metallic-roughness and normal maps, double-sided, as the staged
// oak's and beech's StandardMaterial3D draw them -- canopy_clear.gd copies them in) with one difference:
// above the crown's base, while `fade` is up, an ordered 4x4 dither discards up to (1 - KEEP) of the
// crown's pixels -- and all of them within LENS_CLEAR_M of the eye, where a dotted screen would cover the
// whole view. It stays in the
// OPAQUE pass (a discard, no blending, no sorting, no extra overdraw) and the trunk below the crown is
// untouched. Only the view's own passes thin it: a pass whose camera is not at `eye_position` (the sun's
// shadow cascades) draws the whole crown, so the shadow on the ground does not speckle.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale = 1.0;
// The view camera's world position (canopy_clear.gd sets it each frame a fade is live).
uniform vec3 eye_position = vec3(0.0, -10000.0, 0.0);

// How far the crown is thinned (0: whole, 1: thinned to KEEP), and where the crown begins (world y).
instance uniform float fade : hint_range(0.0, 1.0) = 0.0;
instance uniform float crown_base_y = 0.0;

const float KEEP = 0.25;
const float BLEND_M = 0.6;
const float LENS_CLEAR_M = 5.0;
const float LENS_BLEND_M = 6.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float bayer4(vec2 frag) {
	int x = int(mod(frag.x, 4.0));
	int y = int(mod(frag.y, 4.0));
	const float order[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (order[y * 4 + x] + 0.5) / 16.0;
}

void fragment() {
	float crown = smoothstep(crown_base_y - BLEND_M, crown_base_y + BLEND_M, world_pos.y);
	float lens = 1.0 - smoothstep(LENS_CLEAR_M, LENS_CLEAR_M + LENS_BLEND_M, distance(world_pos, eye_position));
	bool view_pass = distance(CAMERA_POSITION_WORLD, eye_position) < 0.5;
	if (view_pass && fade * crown * max(1.0 - KEEP, lens) > bayer4(FRAGCOORD.xy)) {
		discard;
	}
	vec4 albedo = texture(albedo_texture, UV) * albedo_color;
	ALBEDO = albedo.rgb;
	METALLIC = dot(texture(metallic_texture, UV), metallic_channel) * metallic;
	ROUGHNESS = dot(texture(roughness_texture, UV), roughness_channel) * roughness;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
