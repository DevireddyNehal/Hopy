shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	float band = floor(UV.y * 28.0);
	float tick = floor(TIME * 14.0);
	float lit = step(0.8, hash(band * 1.31 + tick * 7.17));
	vec3 bar_color = vec3(
		hash(band * 2.7 + tick * 3.3),
		hash(band * 4.1 + tick * 5.9),
		hash(band * 6.3 + tick * 1.7)
	);
	float scan = 0.5 + 0.5 * sin(UV.y * 900.0);
	float alpha = (lit * 0.55 + scan * 0.10) * intensity;

	COLOR = vec4(bar_color, alpha);
}
