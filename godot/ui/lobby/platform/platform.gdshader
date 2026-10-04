shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 10.0, 0.5) = 1.0;

void fragment() {
	vec2 pixel = SCREEN_PIXEL_SIZE * outline_width;

	vec4 base = textureLod(screen_texture, SCREEN_UV, 0.0);

	float neighbour_alpha = 0.0;

	neighbour_alpha = max(
		neighbour_alpha,
		textureLod(screen_texture, SCREEN_UV + vec2(pixel.x, 0.0), 0.0).a
	);

	neighbour_alpha = max(
		neighbour_alpha,
		textureLod(screen_texture, SCREEN_UV + vec2(-pixel.x, 0.0), 0.0).a
	);

	neighbour_alpha = max(
		neighbour_alpha,
		textureLod(screen_texture, SCREEN_UV + vec2(0.0, pixel.y), 0.0).a
	);

	neighbour_alpha = max(
		neighbour_alpha,
		textureLod(screen_texture, SCREEN_UV + vec2(0.0, -pixel.y), 0.0).a
	);

	// Diagonals for smoother corners.
	neighbour_alpha = max(
		neighbour_alpha,
		textureLod(screen_texture, SCREEN_UV + vec2(pixel.x, pixel.y), 0.0).a
	);

	neighbour_alpha = max(
		neighbour_alpha,
		textureLod(screen_texture, SCREEN_UV + vec2(-pixel.x, pixel.y), 0.0).a
	);

	neighbour_alpha = max(
		neighbour_alpha,
		textureLod(screen_texture, SCREEN_UV + vec2(pixel.x, -pixel.y), 0.0).a
	);

	neighbour_alpha = max(
		neighbour_alpha,
		textureLod(screen_texture, SCREEN_UV + vec2(-pixel.x, -pixel.y), 0.0).a
	);

	float outline_mask = neighbour_alpha * (1.0 - base.a);

	vec4 result = base;

	if (base.a > 0.0001) {
		// CanvasGroup uses premultiplied alpha internally.
		result.rgb /= base.a;
	} else if (outline_mask > 0.0) {
		result = outline_color;
	}

	COLOR *= result;
}