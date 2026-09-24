shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

// Opaque short fur: fine color fibres, soft rim response and coat markings.
// No alpha, discard, depth fade, vertex displacement or distance fade.
uniform vec4 coat_color : source_color = vec4(0.15, 0.14, 0.16, 1.0);
uniform vec4 dark_color : source_color = vec4(0.04, 0.03, 0.04, 1.0);
uniform vec4 cream_color : source_color = vec4(0.92, 0.89, 0.84, 1.0);
uniform int coat_pattern = 0;
uniform sampler2D fur_texture : filter_linear_mipmap, repeat_enable;
uniform bool use_fur_texture = false;
uniform bool groom_geometry = false;
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
	float visible_detail = clamp(1.0 / max(length(fwidth(p)) * 170.0, 1.0), 0.0, 1.0);
	float grain = mix(0.5, soft_noise(p * 95.0), visible_detail);
	float fibre = sin(p.y * 380.0 + sin(p.x * 135.0) * 1.2 + soft * 8.0) * 0.5 + 0.5;
	fibre = mix(0.5, fibre, visible_detail);
	vec3 fur = coat_color.rgb;
	float head = smoothstep(1.98, 2.24, p.y);
	if (coat_pattern == 1) {
		float around = atan(p.x, p.z - 0.13);
		float bands = sin(around * 6.4 + p.y * 1.9 + soft * 0.65);
		float rear = smoothstep(-0.16, 0.26, p.z);
		float crown = smoothstep(2.87, 3.06, p.y);
		float forehead = smoothstep(0.62, 0.87, sin(p.x * 25.0 + p.y * 0.6 + soft * 0.3));
		float cheek = smoothstep(0.56, 0.78, abs(p.x)) * smoothstep(0.62, 0.9, sin(p.y * 25.0 + p.z * 4.0));
		float stripe = max(smoothstep(0.52, 0.79, bands) * rear, max(forehead * crown, cheek));
		fur = mix(fur, dark_color.rgb, stripe * head * 0.77);
	} else if (coat_pattern == 2) {
		float taper = clamp((2.99 - p.y) * 0.53, 0.025, 0.33);
		float blaze = 1.0 - smoothstep(taper, taper + 0.055, abs(p.x));
		blaze *= (1.0 - smoothstep(-0.35, -0.22, p.z)) * smoothstep(2.30, 2.42, p.y) * (1.0 - smoothstep(2.88, 3.01, p.y));
		fur = mix(fur, cream_color.rgb, blaze);
		// Pumpkin's orange coat has broad tabby bars over the back of the head;
		// these stay visible from the chase camera, unlike a front-only blaze.
		float around = atan(p.x, p.z - 0.13);
		float rear_bands = sin(around * 5.4 + p.y * 1.65 + soft * 0.4);
		rear_bands = smoothstep(0.50, 0.80, rear_bands) * smoothstep(-0.12, 0.24, p.z);
		fur = mix(fur, dark_color.rgb, rear_bands * head * 0.68);
	} else if (coat_pattern == 4 || coat_pattern == 5) {
		// The photographed calico has irregular tortoiseshell islands rather
		// than tabby stripes. Coordinates stay fixed to the animated driver.
		vec3 black_fur = vec3(0.032, 0.025, 0.023);
		vec3 ginger_fur = vec3(0.46, 0.18, 0.052);
		float island = soft_noise(p * vec3(3.3, 3.0, 3.8) + vec3(1.4, 3.6, 0.8));
		float small_edge = soft_noise(p * 18.0) * 0.075;
		float orange_island = smoothstep(0.59, 0.66, island + small_edge);
		if (coat_pattern == 5) {
			orange_island = smoothstep(0.70, 0.79, island + small_edge) * (1.0 - smoothstep(0.18, 0.34, p.y)) * 0.65;
		}
		fur = mix(black_fur, ginger_fur, orange_island);
		if (coat_pattern == 4) {
			float front = 1.0 - smoothstep(-0.22, 0.05, p.z);
			// Positive X appears on the image-left from the front: black.
			// The orange forehead sweeps up the image-right of the nose.
			float orange_forehead = (1.0 - smoothstep(-0.06, 0.035, p.x + sin(p.y * 11.0) * 0.032));
			orange_forehead *= 1.0 - smoothstep(0.54, 0.80, abs(p.x));
			orange_forehead *= smoothstep(2.52, 2.83, p.y);
			vec3 face = mix(black_fur, ginger_fur, orange_forehead);
			float cheek_white = smoothstep(0.16, 0.50, abs(p.x)) * (1.0 - smoothstep(2.41, 2.58, p.y)) * smoothstep(1.98, 2.10, p.y);
			face = mix(face, cream_color.rgb, cheek_white);
			float blaze_width = mix(0.125, 0.036, smoothstep(2.45, 3.10, p.y));
			float blaze_offset = -0.035 - smoothstep(2.62, 3.1, p.y) * 0.04;
			float blaze = 1.0 - smoothstep(blaze_width, blaze_width + 0.025, abs(p.x - blaze_offset + (soft - 0.5) * 0.025));
			blaze *= smoothstep(2.46, 2.53, p.y) * (1.0 - smoothstep(3.05, 3.21, p.y));
			face = mix(face, cream_color.rgb, blaze);
			// Ginger moustache with a white fringe; black beneath the mouth.
			float muzzle = (1.0 - smoothstep(0.35, 0.51, abs(p.x))) * smoothstep(2.09, 2.145, p.y) * (1.0 - smoothstep(2.47, 2.55, p.y));
			face = mix(face, ginger_fur * (0.90 + soft * 0.19), muzzle);
			float cheek_ginger = (1.0 - smoothstep(0.21, 0.41, abs(p.x - 0.23))) * smoothstep(2.02, 2.12, p.y) * (1.0 - smoothstep(2.25, 2.39, p.y));
			face = mix(face, ginger_fur * (0.82 + soft * 0.16), cheek_ginger);
			float throat = (1.0 - smoothstep(0.29, 0.45, abs(p.x))) * (1.0 - smoothstep(2.20, 2.26, p.y)) * smoothstep(-0.76, -0.59, p.z);
			face = mix(face, black_fur, throat);
			fur = mix(fur, face, front * smoothstep(1.98, 2.11, p.y));
			// Keep Mak-Doong's rear coat graphic and broad: a warm crown blaze,
			// two uneven cheek sweeps, and a pale nape. High-frequency islands here
			// used to break into random dots in the chase view.
			float rear_head = smoothstep(-0.10, 0.08, p.z) * smoothstep(1.92, 2.08, p.y);
			float stripe_width = mix(0.30, 0.085, smoothstep(2.18, 3.08, p.y));
			float stripe_center = -0.035 + sin(p.y * 5.1) * 0.026;
			float crown_blaze = 1.0 - smoothstep(stripe_width, stripe_width + 0.055, abs(p.x - stripe_center));
			crown_blaze *= smoothstep(2.12, 2.30, p.y) * (1.0 - smoothstep(3.08, 3.22, p.y));
			float left_sweep = 1.0 - smoothstep(0.055, 0.28, abs(p.x + 0.48 + (p.y - 2.48) * 0.10));
			left_sweep *= smoothstep(2.18, 2.34, p.y) * (1.0 - smoothstep(2.86, 3.02, p.y));
			float right_sweep = 1.0 - smoothstep(0.06, 0.25, abs(p.x - 0.50 - (p.y - 2.45) * 0.08));
			right_sweep *= smoothstep(2.22, 2.38, p.y) * (1.0 - smoothstep(2.78, 2.95, p.y));
			float back_ginger = max(crown_blaze, max(left_sweep * 0.76, right_sweep * 0.66));
			vec3 rear_face = mix(black_fur, ginger_fur, back_ginger);
			float pale_nape = 1.0 - smoothstep(2.04, 2.25, p.y);
			rear_face = mix(rear_face, cream_color.rgb, pale_nape * 0.78);
			fur = mix(fur, rear_face, rear_head);
		}
	} else if (coat_pattern == 3) {
		vec2 mask_point = vec2(p.x / 0.86, (p.y - 2.61) / 0.69);
		float mask = (1.0 - smoothstep(0.70, 1.12, length(mask_point))) * (1.0 - smoothstep(-0.35, -0.13, p.z));
		fur = mix(fur, dark_color.rgb, mask * 0.90);
	}
	if (coat_pattern == 9) {
		float edge = smoothstep(0.20,0.34,UV.x)*(1.0-smoothstep(0.66,0.80,UV.x))*smoothstep(0.13,0.29,UV.y)*(1.0-smoothstep(0.75,0.91,UV.y));
		fur = mix(dark_color.rgb,coat_color.rgb,edge);
	}
	float face_front = 1.0 - smoothstep(-0.29,-0.12,p.z);
	if (coat_pattern == 6) {
		float chin = (1.0-smoothstep(0.62,1.05,length(vec2(p.x/0.40,(p.y-2.08)/0.34)))) * face_front;
		fur = mix(fur,cream_color.rgb,chin);
	} else if (coat_pattern == 8 || coat_pattern == 1) {
		float pads = (1.0-smoothstep(0.33,0.57,abs(p.x))) * (1.0-smoothstep(2.48,2.57,p.y)) * smoothstep(2.08,2.17,p.y) * face_front;
		fur = mix(fur,cream_color.rgb,pads);
	}
	float fur_value = 0.5;
	if (use_fur_texture && !groom_geometry) {
		vec2 texuv = UV * vec2(5.0,3.0);
		fur_value = texture(fur_texture,texuv).r;
		float texel = 0.0008;
		float dx = texture(fur_texture,texuv+vec2(texel,0)).r - texture(fur_texture,texuv-vec2(texel,0)).r;
		float dy = texture(fur_texture,texuv+vec2(0,texel)).r - texture(fur_texture,texuv-vec2(0,texel)).r;
		vec3 micro_normal = normalize(vec3(dx * 1.6, dy * 1.6, 1.0)) * 0.5 + 0.5;
		NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), micro_normal, visible_detail);
	}
	ALBEDO = fur * (0.84 + soft * 0.07 + grain * 0.008 + fur_value * 0.23 + (fibre - 0.5) * 0.035);
	ROUGHNESS = groom_geometry ? 0.96 : 0.82 + grain * 0.12;
	SPECULAR = groom_geometry ? 0.07 : 0.15;
	RIM = groom_geometry ? 0.10 : 0.18;
	RIM_TINT = 0.65;
}
