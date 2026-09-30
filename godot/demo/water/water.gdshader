// The demo's water surface: one material per body. Decision 0196 (live demo), water foundation.
// Presentation only.
//
// Per vertex (water_surface.gd): COLOR.r = depth / 2 m (0..1), COLOR.g = the waterline margin
// mapped 0..1 with 0.5 AT the waterline (1 m inside = 1.0), UV = the surface flow in m/s from the
// integer map -- or, on still water, a slow ripple drift, so stream and pond meet without a seam. Nothing here reads the depth buffer or the screen, so the surface looks the same
// in the underground view (where the ground it lies over is hidden) and costs two texture taps
// per normal layer.
//
// FLOW is a two-phase flow map: two copies of the ripple normals slide along the flow, each
// restarting while the other is fully weighted, so the pattern moves at the water's own speed
// forever without stretching. `flow_phase` (0..1) is advanced by demo_water.gd from the demo
// clock -- it stops dead while the game is paused and runs 2x / 4x with the HUD's speed.
//
// COLOUR: sandy shallows over the visible bed, darkening with depth, a constant sheen of the sky's
// own tones (`sky_color`, `horizon_color`, read from the world's sky) strengthening towards grazing
// angles, soft foam where the water meets the bank, streaks drawn out along the current, and
// broken white water where fast water runs shallow -- which is what makes the ford read as a ford.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color;
uniform vec3 deep_color : source_color;
uniform vec3 horizon_color : source_color;
uniform vec3 sky_color : source_color;
uniform vec3 foam_color : source_color;
uniform sampler2D ripple_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform float flow_phase = 0.0;
uniform float cycle_seconds = 2.0;
uniform float ripple_scale = 0.3;
uniform float normal_depth = 1.0;
uniform float sky_sheen = 0.16;
uniform float shallow_alpha = 0.45;
uniform float deep_alpha = 0.92;
uniform float deep_at = 0.3;
uniform float riffle_depth = 0.14;
uniform float riffle_speed = 0.3;

varying vec2 world_xz;
varying float v_depth;
varying float v_shore;
varying vec2 v_flow;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	v_depth = COLOR.r;
	v_shore = COLOR.g;
	v_flow = UV;
}

// Two copies of a texture sliding along `flow` (m/s), blended so neither is seen restarting.
vec3 flowed(sampler2D tex, vec2 uv, vec2 flow, vec2 offset) {
	float p0 = flow_phase;
	float p1 = fract(flow_phase + 0.5);
	float blend = abs(1.0 - 2.0 * p0);
	vec2 shift = flow * cycle_seconds * ripple_scale;
	vec3 a = texture(tex, uv - shift * p0).rgb;
	vec3 b = texture(tex, uv - shift * p1 + offset).rgb;
	return mix(a, b, blend);
}

void fragment() {
	vec2 flow = v_flow;
	vec2 uv = world_xz * ripple_scale;
	vec3 broad = flowed(ripple_normal, uv, flow, vec2(0.37, 0.61));
	vec3 fine = flowed(ripple_normal, uv * 2.7 + vec2(0.13, 0.71),
		flow * 1.25 + vec2(-flow.y, flow.x) * 0.35, vec2(0.52, 0.18));
	NORMAL_MAP = mix(broad, fine, 0.45);
	NORMAL_MAP_DEPTH = normal_depth;

	float depth_t = smoothstep(0.0, deep_at, v_depth);
	vec3 colour = mix(shallow_color, deep_color, depth_t);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 sky = mix(horizon_color, sky_color, 0.55);
	colour = mix(colour, sky, clamp(sky_sheen + fresnel * 0.6, 0.0, 1.0));

	float speed = length(v_flow);
	vec2 along = speed > 0.001 ? v_flow / speed : vec2(1.0, 0.0);
	vec2 streak_uv = vec2(dot(world_xz, along) * 0.35, dot(world_xz, vec2(-along.y, along.x)) * 2.2);
	float streak = flowed(foam_noise, streak_uv, vec2(speed * 0.35, 0.0), vec2(0.4, 0.1)).r;
	colour *= mix(1.0, mix(0.9, 1.12, streak), smoothstep(0.05, 0.3, speed));

	float shore_m = (v_shore - 0.5) * 2.0;
	float froth = flowed(foam_noise, world_xz * 0.8, flow, vec2(0.21, 0.43)).r;
	float foam = (1.0 - smoothstep(0.0, 0.4, shore_m)) * smoothstep(0.42, 0.72, froth);
	float riffle = (1.0 - smoothstep(0.0, riffle_depth, v_depth)) * smoothstep(0.1, riffle_speed, speed)
		* smoothstep(0.5, 0.8, froth * 0.6 + streak * 0.5) * smoothstep(0.05, 0.3, shore_m);
	colour = mix(colour, foam_color, clamp(foam * 0.55 + riffle * 0.7, 0.0, 0.8));

	ALBEDO = colour;
	ROUGHNESS = 0.09;
	SPECULAR = 0.55;
	METALLIC = 0.0;
	float edge = smoothstep(0.0, 0.1, shore_m);
	ALPHA = mix(shallow_alpha, deep_alpha, depth_t) * edge;
}
