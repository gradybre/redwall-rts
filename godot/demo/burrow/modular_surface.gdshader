shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Procedural authored finish studies. Feature dimensions are visual metres, never gameplay recipes.
uniform int finish_kind = 0;
uniform int surface_kind = 0;
uniform float cut_y = 1000000000.0;
varying vec3 fixed_world;

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

float joint_mask(vec2 at, vec2 size, float width, bool staggered) {
	vec2 p = at / size;
	if (staggered) {
		p.x += mod(floor(p.y), 2.0) * 0.5;
	}
	vec2 edge = min(fract(p), 1.0 - fract(p)) * size;
	float distance_m = min(edge.x, edge.y);
	float aa = max(length(fwidth(at)) * 0.55, 0.001);
	return smoothstep(width, width + aa, distance_m);
}

void vertex() {
	// Mesh vertices are emitted in fixed world coordinates; room resizing never renormalizes UVs.
	fixed_world = VERTEX;
}

void fragment() {
	// One ceiling plane serves both interior and cover views; no duplicate coplanar triangles.
	if (surface_kind != 2 && !FRONT_FACING) {
		discard;
	}
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	if (fixed_world.y > cut_y) {
		discard;
	}
	bool finished = COLOR.r > 0.5 && COLOR.g < 0.5;
	int finish = finished ? finish_kind : 0;
	float broad = noise2(fixed_world.xz * 1.7 + fixed_world.y * vec2(0.8, 0.45));
	float fine = noise2(UV * 24.0);
	float relief = 0.0;
	vec3 color = vec3(0.40, 0.28, 0.17);
	float roughness = 0.96;
	if (finish == 0) {
		float strata = sin(fixed_world.y * 21.0 + broad * 2.4) * 0.026;
		color = mix(vec3(0.27, 0.18, 0.105), vec3(0.49, 0.35, 0.22), broad);
		color *= 0.90 + fine * 0.18 + (surface_kind == 1 ? strata : 0.0);
		relief = broad * 0.018 + fine * 0.0015;
	} else if (finish == 1) {
		vec2 plank_size = vec2(0.22, 1.45);
		vec2 plank = floor(UV / plank_size);
		float seam = joint_mask(UV, plank_size, 0.006, false);
		float grain = noise2(vec2(UV.x * 85.0, UV.y * 3.0 + sin(UV.x * 10.0) * 0.15));
		color = mix(vec3(0.23, 0.115, 0.052), vec3(0.45, 0.28, 0.13), hash21(plank) * 0.5 + 0.25);
		color *= 0.82 + grain * 0.3;
		color = mix(vec3(0.12, 0.07, 0.034), color, seam);
		relief = seam * 0.008 + grain * 0.0018;
		roughness = 0.82;
	} else {
		vec2 block_size = surface_kind == 1 ? vec2(0.62, 0.28) : vec2(0.62, 0.48);
		vec2 block = UV / block_size;
		block.x += mod(floor(block.y), 2.0) * 0.5;
		float seam = joint_mask(UV, block_size, 0.011, true);
		float tone = hash21(floor(block));
		color = mix(vec3(0.33, 0.30, 0.235), vec3(0.58, 0.55, 0.43), tone * 0.72 + broad * 0.28);
		color *= 0.94 + fine * 0.11;
		color = mix(vec3(0.205, 0.185, 0.145), color, seam);
		relief = seam * 0.012 + fine * 0.002;
		roughness = 0.91;
	}
	if (!finished) {
		color *= COLOR.g > 0.5 ? 0.66 : 0.80;
	}
	vec3 dx = dFdx(VERTEX);
	vec3 dy = dFdy(VERTEX);
	vec3 cross_y = cross(dy, NORMAL);
	vec3 cross_x = cross(NORMAL, dx);
	float determinant = dot(dx, cross_y);
	if (abs(determinant) > 0.0000001) {
		NORMAL = normalize(abs(determinant) * NORMAL - sign(determinant) *
			(dFdx(relief) * cross_y + dFdy(relief) * cross_x));
	}
	ALBEDO = color;
	ROUGHNESS = roughness;
	SPECULAR = 0.22;
}
