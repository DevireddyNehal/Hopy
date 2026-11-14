shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_speed = 2.6;

void fragment() {
	if (intensity <= 0.001) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else {
		vec2 uv = SCREEN_UV;
		
		// Full screen drunken nausea wavy liquid warp
		float wave_x = sin(uv.y * 9.0 + TIME * time_speed) * 0.024 * intensity;
		float wave_y = cos(uv.x * 7.0 + TIME * (time_speed * 0.85)) * 0.028 * intensity;
		vec2 distorted_uv = uv + vec2(wave_x, wave_y);
		
		// Chromatic aberration double-vision split
		float split = 0.010 * intensity;
		float r = texture(screen_texture, distorted_uv + vec2(split, 0.0)).r;
		float g = texture(screen_texture, distorted_uv).g;
		float b = texture(screen_texture, distorted_uv - vec2(split, 0.0)).b;
		
		// Subtle dizzy edge tint
		vec2 center_dist = (uv - 0.5) * 2.0;
		float vig = dot(center_dist, center_dist) * 0.20 * intensity;
		vec3 col = vec3(r, g, b);
		col = mix(col, vec3(0.08, 0.28, 0.18), vig * 0.30);
		
		COLOR = vec4(col, 1.0);
	}
}
