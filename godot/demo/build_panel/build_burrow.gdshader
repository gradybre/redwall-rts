shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// THE DUG LEVEL'S EARTH, ROUNDED (decision 1914; decision 1913's look). One surface for the earth's top, the dug
// floors and the rounded walls between them (demo_build_earth.gd, demo_build_burrow.gd). Presentation only.
//   MAPPING   world metres, never the mesh's UVs: the bought floor texture is laid from above, the wall texture
//             from the side the face looks to (triplanar), so a curved wall never stretches either; with nothing
//             staged (CI) the procedural earth of modular_surface.gdshader's packed-earth finish.
//   LIGHT     the dug view's sun lights what is cut, its dim fill only the uncut top (decision 1913 E4), shared
//             smoothly down the first SUN_FROM_M of a cut (the walls round over at the top: no seam).
//   DIGGING   the cell being dug deepens: each vertex moves `dig_share` of the way to its dug height (UV2.x) and
//             its normal to its dug normal (COLOR), a uniform a frame, no rebuild.
//   GRID      a faint 1 m cell grid on the dug cells' floors (UV.x) while `grid_alpha` is set.
//   WET       a level's water mark kept on the cells beside a room (UV.y), unshaded as the earth's own marks.

uniform sampler2D floor_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool floor_textured = false;
uniform bool wall_textured = false;
uniform float floor_tile_m = 4.0;
uniform float wall_tile_m = 2.0;
uniform vec3 top_tint = vec3(0.66);
uniform float top_y = 0.0;
uniform float dig_share = 0.0;
uniform float grid_alpha = 0.0;
uniform vec3 grid_colour : source_color = vec3(0.93, 0.88, 0.74);
uniform vec2 datum_m = vec2(0.0);
uniform vec3 water : source_color = vec3(0.085, 0.12, 0.155);
uniform vec3 fill_toward = vec3(0.0, 1.0, 0.01);
const float SUN_FROM_M = 0.12;

varying vec3 world;
varying vec3 world_normal;
varying vec3 fill_view;
varying float grid_flag;
varying float wet;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
	VERTEX.y += dig_share * UV2.x;
	NORMAL = normalize(mix(NORMAL, COLOR.rgb * 2.0 - 1.0, dig_share));
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	fill_view = normalize((VIEW_MATRIX * vec4(normalize(fill_toward), 0.0)).xyz);
	grid_flag = UV.x;
	wet = UV.y;
}

vec3 procedural(vec3 at, float wallness) {
	// modular_surface.gdshader's packed earth (finish 0), its fine grain taken from the face's own plane.
	float broad = noise2(at.xz * 1.7 + at.y * vec2(0.8, 0.45));
	float fine = mix(noise2(at.xz * 24.0), noise2(vec2(at.x + at.z, at.y) * 24.0), wallness);
	float strata = sin(at.y * 21.0 + broad * 2.4) * 0.026 * wallness;
	return mix(vec3(0.27, 0.18, 0.105), vec3(0.49, 0.35, 0.22), broad) * (0.90 + fine * 0.18 + strata);
}

vec3 wall_colour(vec3 at, vec3 n) {
	if (!wall_textured) {
		return procedural(at, 1.0);
	}
	vec2 side = pow(abs(n.xz), vec2(4.0)) + vec2(0.0001);
	side /= side.x + side.y;
	vec3 across_x = texture(wall_texture, vec2(at.z, -at.y) / wall_tile_m).rgb;
	vec3 across_z = texture(wall_texture, vec2(at.x, -at.y) / wall_tile_m).rgb;
	return across_x * side.x + across_z * side.y;
}

vec3 floor_colour(vec3 at) {
	return floor_textured ? texture(floor_texture, vec2(at.x, -at.z) / floor_tile_m).rgb : procedural(at, 0.0);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float level = smoothstep(0.6, 0.9, n.y);
	vec3 colour = mix(wall_colour(world, n), floor_colour(world), level);
	float cut = clamp((top_y - world.y) / SUN_FROM_M, 0.0, 1.0);
	colour *= mix(top_tint, vec3(1.0), cut);
	vec2 cell = world.xz - datum_m;
	vec2 edge = abs(fract(cell - 0.5) - 0.5) / max(fwidth(cell), vec2(0.001));
	float line = (1.0 - clamp(min(edge.x, edge.y), 0.0, 1.0)) * grid_alpha * step(0.5, grid_flag);
	colour = mix(colour, grid_colour, line);
	ALBEDO = colour * (1.0 - wet);
	EMISSION = water * wet + grid_colour * line * 0.25;
	ROUGHNESS = 1.0;
}

void light() {
	// The fill shines from straight above; any other light is the dug view's sun.
	float below = clamp((top_y - world.y) / SUN_FROM_M, 0.0, 1.0);
	float share = dot(LIGHT, fill_view) > 0.999 ? 1.0 - below : below;
	DIFFUSE_LIGHT += share * clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI;
}
