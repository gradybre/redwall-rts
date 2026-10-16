// THE MOUNDS' HILL (decision 2002; demo_build_mound_hill.gd). One surface in world metres. The vertex colour is the
// colour (linear) and its alpha says what the point is: 1 turf, 0.5 a dug floor, 0.25 heaped earth, 0 cut earth
// (demo_build_mound_mesh.gd). All are broken up by fixed value noise; where the build panel's bought earth textures are
// staged (decision 1913), a dug floor wears the floor texture from above, heaped earth the same packed earth from the
// side it faces, and cut earth the wall texture from the side it faces (triplanar), each tinted by the vertex colour.
// Nothing staged (CI): the colours and noise alone.
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D floor_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D wall_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform bool floor_textured = false;
uniform bool wall_textured = false;
uniform float floor_tile_m = 4.0;
uniform float wall_tile_m = 2.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 triplanar(sampler2D tex, float tile_m, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	vec3 x = texture(tex, p.zy / tile_m).rgb;
	vec3 y = texture(tex, p.xz / tile_m).rgb;
	vec3 z = texture(tex, p.xy / tile_m).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	float kind = COLOR.a;
	float n = value_noise(world_position.xz * 1.7) * 0.6 + value_noise(world_position.xz * 5.3) * 0.4;
	vec3 albedo = COLOR.rgb * (0.82 + 0.36 * n);
	if (kind < 0.125 && wall_textured) {
		albedo = triplanar(wall_texture, wall_tile_m, world_position, world_normal) * COLOR.rgb * 2.2;
	} else if (kind < 0.375 && kind >= 0.125 && floor_textured) {
		albedo = triplanar(floor_texture, floor_tile_m, world_position, world_normal) * COLOR.rgb * 2.0;
	} else if (kind < 0.75 && kind >= 0.375 && floor_textured) {
		albedo = texture(floor_texture, world_position.xz / floor_tile_m).rgb * COLOR.rgb * 2.0;
	}
	ALBEDO = albedo;
	ROUGHNESS = 0.95;
}
