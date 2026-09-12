shader_type spatial;
render_mode cull_back, diffuse_toon, specular_disabled;

// Simple mobile toon: albedo ramp + optional rim.
uniform vec4 albedo : source_color = vec4(0.9, 0.9, 0.9, 1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform float shadow_threshold : hint_range(0.0, 1.0) = 0.45;
uniform float shadow_softness : hint_range(0.001, 0.5) = 0.08;
uniform vec4 shadow_tint : source_color = vec4(0.55, 0.6, 0.75, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.15;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	ALBEDO = albedo.rgb * tex.rgb;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
}

void light() {
	float ndotl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float toon = smoothstep(shadow_threshold - shadow_softness, shadow_threshold + shadow_softness, ndotl);
	vec3 lit = mix(ALBEDO * shadow_tint.rgb, ALBEDO, toon);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * rim_strength;
	DIFFUSE_LIGHT += rim_color.rgb * rim * ATTENUATION;
}
