// The bank-and-bed film over the carved ground. Decision 0196 (live demo), water foundation.
// Presentation only.
//
// Per vertex (water_terrain.gd): COLOR.r = wetness, 0 at the bank top and 1 at the waterline and
// below; COLOR.g = depth / 2 m. Damp earth rises from the waterline and frays into the grass above
// it; under the water the bed darkens with depth. All sampled in world XZ, like the ground.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 mud_dry : source_color;
uniform vec3 mud_wet : source_color;
uniform vec3 bed_color : source_color;
uniform sampler2D noise : filter_linear_mipmap, repeat_enable;

varying vec2 world_xz;
varying float v_wet;
varying float v_depth;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	v_wet = COLOR.r;
	v_depth = COLOR.g;
}

void fragment() {
	float broad = texture(noise, world_xz * 0.35).r;
	float fine = texture(noise, world_xz * 1.7 + vec2(0.3, 0.8)).r;
	float wet = clamp(v_wet + (broad - 0.5) * 0.3, 0.0, 1.0);
	vec3 colour = mix(mud_dry, mud_wet, smoothstep(0.45, 0.95, wet));
	colour = mix(colour, bed_color, smoothstep(0.0, 0.5, v_depth));
	colour *= mix(0.88, 1.08, fine);
	ALBEDO = colour;
	ROUGHNESS = mix(0.95, 0.45, smoothstep(0.75, 1.0, wet));
	SPECULAR = 0.35;
	ALPHA = smoothstep(0.3, 0.72, v_wet + (broad - 0.5) * 0.35);
}
