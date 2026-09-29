// Crop plant cards: alpha-scissor foliage over an atlas of real rendered plants. Decision 0196.
//
// The atlas holds `variants` cells side by side; each MultiMesh instance picks its cell through
// INSTANCE_CUSTOM.r. Scissor, not blend, so the cards cast shadows and sort like solid geometry.
// (Alpha-to-coverage was tried and dithered the stalks into a visible screen-door.) Coverage is kept up at a distance by
// scaling alpha with the mip level, otherwise thin stalks thin out and vanish in the small mips.
// The normal is bent toward world up so a bed of cards is lit as one mass of foliage rather than
// as flat panels facing every way; the base of each plant is shaded down as the stand's own
// occlusion, and light through the leaves comes back as backlight.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float variants = 1.0;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.5;
uniform float up_bend : hint_range(0.0, 1.0) = 0.5;
uniform float base_shade : hint_range(0.0, 1.0) = 0.45;
uniform float backlight = 0.12;

varying float shade;

void vertex() {
	shade = mix(base_shade, 1.0, smoothstep(1.0, 0.35, UV.y));
	UV.x = (UV.x + INSTANCE_CUSTOM.r) / variants;
}

void fragment() {
	vec4 texel = texture(atlas, UV);
	float lod = max(textureQueryLod(atlas, UV).y, 0.0);
	ALBEDO = texel.rgb * shade;
	ALPHA = clamp(texel.a * (1.0 + lod * 0.3), 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up, up_bend));
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	BACKLIGHT = texel.rgb * backlight;
}
