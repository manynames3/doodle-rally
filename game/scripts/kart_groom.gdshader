shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled, shadows_disabled;

// Opaque short fur: fine color fibres, soft rim response and coat markings.
// No alpha, discard, depth fade, vertex displacement or distance fade.
uniform vec4 coat_color : source_color = vec4(0.15, 0.14, 0.16, 1.0);
uniform vec4 dark_color : source_color = vec4(0.04, 0.03, 0.04, 1.0);
uniform vec4 cream_color : source_color = vec4(0.92, 0.89, 0.84, 1.0);
uniform int coat_pattern = 0;
varying vec3 groom_color;

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

// Coat masks run per vertex; strand fragments have no noise or texture work.
void vertex() {
	vec3 p = VERTEX;
	float soft = 0.5;
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
	} else if (coat_pattern == 4 || coat_pattern == 5) {
		// The photographed calico has irregular tortoiseshell islands rather
		// than tabby stripes. Coordinates stay fixed to the animated driver.
		vec3 black_fur = vec3(0.032, 0.025, 0.023);
		vec3 ginger_fur = vec3(0.38, 0.145, 0.045);
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
			// Keep the rear-facing head consistent with the photographed calico:
			// broad black/ginger patches and one soft white crown stripe.
			float rear_head = smoothstep(-0.12, 0.18, p.z) * smoothstep(2.00, 2.38, p.y);
			// Match the broad asymmetrical islands on the supplied Mak-Doong sheet.
			float back_patch_a = 1.0 - smoothstep(0.08, 0.64, length(vec2((p.x + 0.30) * 1.15, (p.y - 2.60) * 0.78)));
			back_patch_a *= smoothstep(2.14, 2.34, p.y) * (1.0 - smoothstep(3.02, 3.18, p.y));
			float back_patch_b = 1.0 - smoothstep(0.10, 0.56, length(vec2((p.x - 0.28) * 1.10, (p.y - 2.48) * 0.82)));
			back_patch_b *= smoothstep(2.18, 2.54, p.y) * (1.0 - smoothstep(2.92, 3.13, p.y));
			float back_ginger = max(back_patch_a * 0.78, back_patch_b * 0.60);
			vec3 rear_face = mix(black_fur, ginger_fur, back_ginger);
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
	groom_color = fur * 0.92;
}

void fragment() {
	ALBEDO = groom_color;
	ROUGHNESS = 0.97;
	SPECULAR = 0.0;
}
