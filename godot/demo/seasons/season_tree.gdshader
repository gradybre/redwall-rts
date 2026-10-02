// A staged tree in leaf: the season's tint, blossom and cover, and NO discard. Decision 0551. Presentation.
//
// The tree shader (demo/camera/canopy_fade.gdshader) can drop leaves and thin a crown, and a shader that can
// discard is drawn through its own fragment in the depth prepass and in every shadow cascade. A tree with no
// leaf dropped -- every tree in spring and summer and most of autumn -- needs neither, so season_view.gd draws it
// in this variant, which the renderer can shadow and prepass as plain opaque geometry; only a tree with leaves
// down wears the tree shader. The two take the same parameters (canopy_clear.gd make_fade_material fills both;
// test_demo_seasons.gd holds their lists equal), so a tree changes variant without a seam.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_scale : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D metallic_texture : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : hint_roughness_g, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 metallic_channel = vec4(0.0, 0.0, 1.0, 0.0);
uniform vec4 roughness_channel = vec4(0.0, 1.0, 0.0, 0.0);
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_scale = 1.0;

#include "res://demo/seasons/season_leaves.gdshaderinc"

// The tree shader's own (unused here: this variant never thins), so both take the same parameters.
uniform vec3 eye_position = vec3(0.0, -10000.0, 0.0);
instance uniform float fade : hint_range(0.0, 1.0) = 0.0;
instance uniform float crown_base_y = 0.0;

varying float model_y;

void vertex() {
	model_y = VERTEX.y;
}

void fragment() {
	vec4 albedo = texture(albedo_texture, UV) * albedo_color;
	float leaf = leafness(albedo.rgb, model_y);
	float up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y;
	ALBEDO = season_albedo(albedo.rgb, leaf, UV, up);
	METALLIC = dot(texture(metallic_texture, UV), metallic_channel) * metallic;
	ROUGHNESS = dot(texture(roughness_texture, UV), roughness_channel) * roughness_scale;
	NORMAL_MAP = texture(normal_texture, UV).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
