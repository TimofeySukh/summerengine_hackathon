shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded, depth_draw_never;

uniform float radius : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float ring_width : hint_range(0.01, 0.4, 0.01) = 0.11;
uniform vec4 wave_color : source_color = vec4(0.35, 0.88, 1.0, 0.95);
uniform float intensity = 2.4;
uniform float edge_softness = 0.025;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float dist = length(centered);

	float inner = radius - ring_width * 0.5;
	float outer = radius + ring_width * 0.5;
	float ring = smoothstep(inner, inner + edge_softness, dist)
		* (1.0 - smoothstep(outer - edge_softness, outer, dist));

	float trail = smoothstep(radius - ring_width, radius, dist)
		* (1.0 - smoothstep(radius, radius + ring_width * 0.35, dist)) * 0.35;

	float alpha = (ring + trail) * wave_color.a;
	ALBEDO = wave_color.rgb;
	ALPHA = alpha;
	EMISSION = wave_color.rgb * intensity * (ring + trail * 0.5);
}
