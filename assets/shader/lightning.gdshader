shader_type canvas_item;
render_mode blend_add;

// 简洁的闪电特效：两条随时间抖动的电弧叠加，并带轻微扰动与闪烁
// 可调参数：
uniform vec4 lightning_color : source_color = vec4(0.60, 0.85, 1.00, 1.0);
uniform float speed = 1.8;        // 电弧抖动速度
uniform float intensity = 1.0;    // 叠加强度（整体亮度）
uniform float thickness = 0.02;   // 电弧核心粗细

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

float lightning_line(vec2 uv, float y_center, float amp, float freq, float core_thickness, float t) {
    // 生成一条在 y_center 附近的曲折电弧
    float y = y_center;
    y += sin(uv.x * freq + t * 3.0) * amp;
    y += sin(uv.x * (freq * 0.73) - t * 1.7) * (amp * 0.55);
    // 与电弧的距离
    float d = abs(uv.y - y);
    // 核心亮度（越近越亮）
    float core = smoothstep(core_thickness, 0.0, d);
    // 外圈微光
    float glow = smoothstep(0.12, 0.0, d) * 0.45;
    return clamp(core + glow, 0.0, 1.0);
}

void fragment() {
    vec2 uv = UV;
    float t = TIME * speed;

    // 近电弧处的轻微扰动，用于采样原始贴图形成热扭曲
    float jitter = (sin(uv.x * 40.0 + t * 15.0) * 0.003) + (sin(uv.y * 30.0 - t * 11.0) * 0.002);
    vec2 disp_uv = uv + vec2(0.0, jitter);

    // 叠加两条电弧
    float bolt_a = lightning_line(uv, 0.52, 0.08, 16.0, thickness, t);
    float bolt_b = lightning_line(uv, 0.22, 0.06, 11.0, thickness * 0.85, t);
    float bolts = clamp(bolt_a + bolt_b, 0.0, 1.0);

    // 随机闪烁（高频）
    float flicker = 0.7 + 0.3 * sin(t * 20.0 + hash(uv * vec2(120.0, 80.0) + t) * 6.2831);

    vec4 base = texture(TEXTURE, disp_uv);
    vec3 add_glow = lightning_color.rgb * (bolts * flicker * intensity);

    COLOR = vec4(clamp(base.rgb + add_glow, vec3(0.0), vec3(1.0)), base.a);
}