shader_type canvas_item;

uniform sampler2D noise_texture;

uniform float noise_speed : hint_range(0.0, 4.0, 0.01) = 1.2;
uniform float noise_size  : hint_range(0.0, 1.5, 0.01) = 0.8;
uniform vec4 edge_color   : source_color = vec4(1.0, 0.45, 0.05, 1.0);

// 新增：闪烁与涡旋，提高动态感
uniform float flicker_speed  : hint_range(0.0, 10.0, 0.01) = 2.5;
uniform float flicker_strength : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float swirl           : hint_range(0.0, 0.1, 0.001) = 0.02;

void fragment(){
    vec4 base_color = texture(TEXTURE, UV);
    
    // 噪声采样随时间向上滚动，并叠加轻微 x 方向涡旋
    vec2 noise_uv = UV;
    noise_uv.y += TIME * noise_speed;
    noise_uv.x += sin(UV.y * 10.0 + TIME * noise_speed * 1.2) * swirl;
    vec4 noise_color = texture(noise_texture, noise_uv);
    float noise = pow(noise_color.r, 5.0) * noise_size;
    
    // 额外抖动，增强火焰跳动感
    vec2 jitter = vec2(
        sin(UV.y * 40.0 + TIME * noise_speed * 8.0),
        cos(UV.x * 35.0 - TIME * noise_speed * 7.0)
    ) * (0.002 + 0.004 * noise_size);
    
    vec2 uv_1 = clamp(UV + noise + jitter, vec2(0.0), vec2(1.0));
    vec2 uv_2 = clamp(UV - noise - jitter, vec2(0.0), vec2(1.0));
    
    // 提取透明通道并叠加两次采样
    float tex_color_a = texture(TEXTURE, uv_1).a + texture(TEXTURE, uv_2).a;
    tex_color_a = clamp(tex_color_a, 0.0, 1.0);
    
    // 闪烁因子
    float flicker = 1.0 + sin(TIME * flicker_speed + UV.x * 12.0 + UV.y * 8.0) * flicker_strength;
    
    // 边缘颜色
    vec4 _edge_color = edge_color;
    _edge_color.a = edge_color.a * tex_color_a * flicker;
    
    vec4 outline_color = mix(base_color, _edge_color, clamp(tex_color_a - base_color.a, 0.0, 1.0));
    COLOR = outline_color;
}