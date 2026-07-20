shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 warning_color : source_color = vec4(1.0, 0.62, 0.12, 1.0);
uniform vec4 danger_color : source_color = vec4(1.0, 0.06, 0.03, 1.0);


void fragment() {
	float nearest_edge = min(
		min(UV.x, 1.0 - UV.x),
		min(UV.y, 1.0 - UV.y)
	);
	float edge_width = mix(0.065, 0.26, intensity);
	float edge_mask = 1.0 - smoothstep(0.0, edge_width, nearest_edge);
	float presence = smoothstep(0.01, 0.32, intensity);

	// The bands move upward so a fast fall reads as the world rushing past.
	float flow = UV.y * 72.0 + TIME * mix(3.0, 12.0, intensity);
	flow += sin(UV.x * 22.0) * 1.8;
	float streak = pow(0.5 + 0.5 * sin(flow), 6.0);
	float pulse = 0.9 + 0.1 * sin(TIME * mix(2.0, 7.0, intensity));

	float danger_mix = smoothstep(0.32, 0.72, intensity);
	vec4 tint = mix(warning_color, danger_color, danger_mix);
	float alpha = edge_mask * presence * mix(0.08, 0.52, intensity);
	alpha *= mix(0.72, 1.0, streak) * pulse;

	COLOR = vec4(tint.rgb, alpha * tint.a);
}
