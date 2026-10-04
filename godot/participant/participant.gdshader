shader_type canvas_item;
render_mode blend_premul_alpha;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float invisibility_amount : hint_range(0.0, 1.0) = 0.0;
uniform float reveal_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 tex = texture(screen_texture, SCREEN_UV);
    float effective_invisibility = mix(invisibility_amount, 0.0, reveal_amount);
    float fade = 1.0 - effective_invisibility;
    float alpha = tex.a * fade;

    tex.rgb = mix(tex.rgb * fade, vec3(alpha), flash_amount);
    tex.a = alpha;

    COLOR = tex;
}
