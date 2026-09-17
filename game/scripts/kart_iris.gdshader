shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec4 iris_color : source_color = vec4(0.5,0.6,0.2,1.0);
void fragment() {
	vec2 p = (UV - vec2(0.5))*2.0;
	float r = length(p);
	float a = atan(p.y,p.x);
	float ray = sin(a*37.0 + sin(a*13.0)*1.4 + r*13.0)*0.5+0.5;
	float filaments = sin(a*71.0-r*24.0+sin(a*31.0))*0.5+0.5;
	// Keep the pupil expressive but leave a broader colored iris ring so the
	// faces read as soft kittens instead of glossy toy eyes.
	float pupil = smoothstep(0.34,0.45,length(vec2(p.x*1.18,p.y)));
	vec3 iris = iris_color.rgb * (0.31 + ray*0.07 + filaments*0.045);
	iris = mix(iris*0.42,iris,smoothstep(0.64,0.74,r));
	iris = mix(iris,vec3(0.016,0.021,0.022),smoothstep(0.79,0.98,r));
	vec3 color = mix(vec3(0.006,0.012,0.015),iris,pupil);
	float highlight = (1.0-smoothstep(0.08,0.15,length((p-vec2(-0.25,0.30))*vec2(1.0,1.28))));
	float small = 1.0-smoothstep(0.025,0.055,length(p-vec2(0.28,-0.20)));
	ALBEDO = mix(color,vec3(0.92,0.97,1.0),max(highlight,small)*0.18);
	ROUGHNESS = 0.56;
	SPECULAR = 0.13;
	CLEARCOAT = 0.0;
	CLEARCOAT_ROUGHNESS = 0.28;
}
