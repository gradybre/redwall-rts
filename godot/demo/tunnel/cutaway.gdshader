// The small cutaway shader: a prop in a bore drawn only below a world height. Decision 0207 (the
// underground revamp's P1; design docs/design/underground_revamp.md §5 "Walls": braces and lanterns
// discard above the crown, so beams do not hide residents). The brace frames (tunnel_marks.gd) are drawn
// with it: their posts stand, their cap beam -- the part over a walker's head -- is cut away. Its albedo
// map and tint are copied from the prop's own material when it is built.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform vec4 albedo_colour : source_color = vec4(1.0);
uniform float roughness = 0.9;
uniform float cut_y = -0.63;

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (world_y > cut_y) {
		discard;
	}
	ALBEDO = texture(albedo_texture, UV).rgb * albedo_colour.rgb;
	ROUGHNESS = roughness;
}
