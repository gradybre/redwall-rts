// The seasons on a tree's leaves. Decision 0551. Presentation only. Included by the tree shader
// (demo/camera/canopy_fade.gdshader), which every staged tree wears all year (season_view.gd).
//
// Per tree (instance uniforms; season_view.gd writes them from season_look.gd when the calendar's hour turns):
//   leaf_tint     rgb: a LINEAR hue scaled by the season's value lift, multiplied here by each leaf texel's own
//                 luminance (so the texture's light and shade stay); a: how far the leaves take it (0: summer).
//   leaf_bare     the share of leaf texels dropped: an opaque-pass discard by UV cell, so whole clumps go.
//   leaf_blossom  the share of the spring flowering speckle shown.
// Per material: the weather's frost and snow (cover.gdshaderinc), lying on what faces up -- the bare limbs in
// winter, the leaves of a tree that keeps them.
//
// A texel is LEAF by its colour: green over red in linear light (the staged oak's leaves run ~1.6, its bark
// ~0.85, the beech's grey bark ~0.95), and green over blue -- and by where it is: the moss the texture paints on
// the roots and the trunk's foot is as green as a leaf, so nothing in the model's own bottom share (`roots_y`, in
// the mesh's own units, set per model by season_view.gd from its bound: bare_boughs.gd ROOTS_SHARE) is leaf. In
// the model's own units, so a sapling, a young tree drawn small and a felled crown lying on the ground keep the
// same mask as a standing tree. Bark and moss are never dropped or tinted.

#include "res://demo/weather/cover.gdshaderinc"

instance uniform vec4 leaf_tint = vec4(1.0, 1.0, 1.0, 0.0);
instance uniform float leaf_bare = 0.0;
instance uniform float leaf_blossom = 0.0;
uniform vec3 blossom_color : source_color = vec3(0.86, 0.84, 0.6);

const float LEAF_RATIO_LO = 1.08;
const float LEAF_RATIO_HI = 1.35;
// Leaves drop in UV cells this fine (a 2048 texture: ~28 texels a cell, a clump of leaves).
const float DROP_CELLS = 72.0;
const float BLOSSOM_CELLS = 220.0;
const float BLOSSOM_SHARE = 0.12;
// A flower is a round dot this wide in its cell (a share of the cell).
const float BLOSSOM_RADIUS = 0.32;
// Below x (the mesh's own height) a texel is root or trunk foot (moss, not leaf), easing to leaf over y.
uniform vec2 roots_y = vec2(-100000.0, 1.0);
// How much of the weather's cover lies on a tree's upward faces.
const float TREE_COVER = 0.8;

float season_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

// How much a texel (linear albedo) at the mesh's own height `model_y` is leaf, 0..1.
float leafness(vec3 albedo, float model_y) {
	float ratio = albedo.g / max(albedo.r, 0.002);
	float above_roots = smoothstep(roots_y.x, roots_y.x + roots_y.y, model_y);
	return smoothstep(LEAF_RATIO_LO, LEAF_RATIO_HI, ratio) * step(albedo.b, albedo.g) * above_roots;
}

// Whether this leaf texel has fallen.
bool season_drops(float leaf, vec2 uv) {
	return leaf_bare > 0.0 && leaf > 0.5 && season_hash(floor(uv * DROP_CELLS)) < leaf_bare;
}

// The texel's albedo in the season: tinted where it is leaf, flowering, and under the weather's cover.
vec3 season_albedo(vec3 albedo, float leaf, vec2 uv, float up) {
	float luma = dot(albedo, vec3(0.2126, 0.7152, 0.0722));
	vec3 colour = mix(albedo, leaf_tint.rgb * luma, leaf_tint.a * leaf);
	vec2 cell = uv * BLOSSOM_CELLS;
	float dot_ = 1.0 - smoothstep(BLOSSOM_RADIUS * 0.6, BLOSSOM_RADIUS, length(fract(cell) - 0.5));
	float bloom = leaf_blossom * leaf * dot_ * step(season_hash(floor(cell) + 17.0), BLOSSOM_SHARE);
	colour = mix(colour, blossom_color, bloom);
	return cover_albedo(colour, snow_cover * TREE_COVER * smoothstep(0.45, 0.85, up));
}
