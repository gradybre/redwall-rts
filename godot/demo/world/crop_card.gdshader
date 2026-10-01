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
// A colour laid over the plants (white: none). The farm (demo/farm/) tints a bed by its crop and stage.
uniform vec3 tint = vec3(1.0);
// A withered bed's leaves bleach toward dry straw; a blighted bed's are blotched with dark spots
// (farm_look.gd bleach / spots). 0 draws the plant as rendered.
uniform float bleach : hint_range(0.0, 1.0) = 0.0;
uniform float spots : hint_range(0.0, 1.0) = 0.0;
const vec3 STRAW = vec3(0.62, 0.48, 0.3);
const vec3 BLIGHT = vec3(0.1, 0.08, 0.06);
const float SPOT_CELLS = 22.0;

varying float shade;
varying vec2 plant_uv;

// A blotch pattern over the plant: in some cells of a grid, a dark disc of varying size.
float blotch(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float h = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	vec2 centre = vec2(fract(h * 7.13), fract(h * 3.71)) * 0.6 + 0.2;
	float radius = mix(0.12, 0.36, fract(h * 11.3));
	return step(0.45, h) * (1.0 - smoothstep(radius * 0.7, radius, distance(local, centre)));
}

void vertex() {
	shade = mix(base_shade, 1.0, smoothstep(1.0, 0.35, UV.y));
	plant_uv = UV;
	UV.x = (UV.x + INSTANCE_CUSTOM.r) / variants;
}

void fragment() {
	vec4 texel = texture(atlas, UV);
	float lod = max(textureQueryLod(atlas, UV).y, 0.0);
	vec3 colour = texel.rgb;
	float luma = dot(colour, vec3(0.3, 0.59, 0.11));
	colour = mix(colour, STRAW * (0.55 + luma), bleach);
	colour = mix(colour, BLIGHT, spots * blotch(plant_uv * vec2(SPOT_CELLS * 0.6, SPOT_CELLS)));
	ALBEDO = colour * shade * tint;
	ALPHA = clamp(texel.a * (1.0 + lod * 0.3), 0.0, 1.0);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	vec3 up = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	NORMAL = normalize(mix(NORMAL, up, up_bend));
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
	BACKLIGHT = colour * tint * backlight;
}
