shader_type canvas_item;

// Animate within the single photographed rear sprite, so there is no second
// cutout or exposed seam around the fur, halo, tires, or steering wheel.
uniform vec2 head_center = vec2(0.5, 0.24);
uniform vec2 head_radius = vec2(0.34, 0.29);
uniform vec2 tail_center = vec2(0.2, 0.5);
uniform vec2 tail_radius = vec2(0.18, 0.18);
uniform float look = 0.0;
uniform float tail_wag = 0.0;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec2 head_delta = UV - head_center;
	float head_weight = 1.0 - smoothstep(0.62, 1.23, length(head_delta / head_radius));
	float tail_weight = 1.0 - smoothstep(0.52, 1.20, length((UV - tail_center) / tail_radius));
	vec2 sample_uv = UV;
	// The top of the head leans toward the highlighted course. The neck stays
	// almost fixed, while the separate tail region sways gently at idle.
	sample_uv.x -= head_weight * (look * 0.050 + head_delta.y * look * 0.14);
	sample_uv.y += head_weight * head_delta.x * look * 0.090;
	sample_uv.x -= tail_weight * tail_wag * 0.028;
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, sample_uv) * vertex_tint;
	}
}
