shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Opaque short fur: fine color fibres, soft rim response and coat markings.
// No alpha, discard, depth fade, vertex displacement or distance fade.
uniform vec4 coat_color : source_color = vec4(0.15, 0.14, 0.16, 1.0);
uniform vec4 dark_color : source_color = vec4(0.04, 0.03, 0.04, 1.0);
uniform vec4 cream_color : source_color = vec4(0.92, 0.89, 0.84, 1.0);
uniform int coat_pattern = 0;
varying vec3 fur_position;

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.11369, 0.13787));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float soft_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash31(i), hash31(i + vec3(1, 0, 0)), f.x),
		mix(hash31(i + vec3(0, 1, 0)), hash31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash31(i + vec3(0, 0, 1)), hash31(i + vec3(1, 0, 1)), f.x),
		mix(hash31(i + vec3(0, 1, 1)), hash31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	fur_position = VERTEX;
}

void fragment() {
	vec3 p = fur_position;
	float soft = soft_noise(p * 12.0);
	float grain = soft_noise(p * 95.0);
	float fibre = sin(p.y * 380.0 + sin(p.x * 135.0) * 1.2 + soft * 8.0) * 0.5 + 0.5;
	float visible_detail = clamp(1.0 / max(length(fwidth(p)) * 170.0, 1.0), 0.0, 1.0);
	fibre = mix(0.5, fibre, visible_detail);
	vec3 fur = coat_color.rgb;
	float head = smoothstep(1.98, 2.24, p.y);
	if (coat_pattern == 1) {
		float around = atan(p.x, p.z - 0.13);
		float bands = sin(around * 9.0 + p.y * 2.3 + soft * 0.8);
		float rear = smoothstep(-0.16, 0.26, p.z);
		float crown = smoothstep(2.87, 3.06, p.y);
		float forehead = smoothstep(0.62, 0.87, sin(p.x * 25.0 + p.y * 0.6 + soft * 0.3));
		float cheek = smoothstep(0.56, 0.78, abs(p.x)) * smoothstep(0.62, 0.9, sin(p.y * 25.0 + p.z * 4.0));
		float stripe = max(smoothstep(0.58, 0.84, bands) * rear, max(forehead * crown, cheek));
		fur = mix(fur, dark_color.rgb, stripe * head * 0.77);
	} else if (coat_pattern == 2) {
		float taper = clamp((2.99 - p.y) * 0.53, 0.025, 0.33);
		float blaze = 1.0 - smoothstep(taper, taper + 0.055, abs(p.x));
		blaze *= (1.0 - smoothstep(-0.35, -0.22, p.z)) * smoothstep(2.30, 2.42, p.y) * (1.0 - smoothstep(2.88, 3.01, p.y));
		fur = mix(fur, cream_color.rgb, blaze);
	} else if (coat_pattern == 3) {
		vec2 mask_point = vec2(p.x / 0.86, (p.y - 2.61) / 0.69);
		float mask = (1.0 - smoothstep(0.70, 1.12, length(mask_point))) * (1.0 - smoothstep(-0.35, -0.13, p.z));
		fur = mix(fur, dark_color.rgb, mask * 0.90);
	}
	ALBEDO = fur * (0.925 + soft * 0.08 + grain * 0.025 + fibre * 0.025);
	ROUGHNESS = 0.86 + grain * 0.10;
	SPECULAR = 0.18;
	RIM = 0.16;
	RIM_TINT = 0.65;
}
