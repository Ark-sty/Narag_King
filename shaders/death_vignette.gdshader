shader_type canvas_item;
render_mode unshaded;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 centered_uv = UV - vec2(0.5);
	float dist = length(centered_uv) * 2.0;
	float inner_edge = mix(1.3, 0.25, intensity);
	float vignette = smoothstep(inner_edge, 1.45, dist);
	COLOR = vec4(vignette_color.rgb, vignette * mix(0.0, 0.92, intensity));
}
