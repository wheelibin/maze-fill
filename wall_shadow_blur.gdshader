shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius : hint_range(0.0, 40.0) = 14.0;

// shortcut: fixed 5x5-tap box blur, not a true separable gaussian —
// plenty smooth at the small radius this effect needs; upgrade to a
// two-pass separable blur if a much larger radius is ever wanted.
void fragment() {
	vec2 texel = SCREEN_PIXEL_SIZE * (blur_radius / 2.0);
	vec4 sum = vec4(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			sum += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(float(x), float(y)) * texel);
		}
	}
	COLOR = sum / 25.0;
}
