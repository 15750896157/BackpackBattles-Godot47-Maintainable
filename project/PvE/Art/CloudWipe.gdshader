shader_type canvas_item;
render_mode unshaded;
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform bool uncover = false;
uniform bool reduced_motion = false;
uniform bool reduced_flash = false;
// 云图放大倍数：让云铺满整个屏幕，而不是只在中间露出一团
const float CLOUD_ZOOM = 1.65;
void fragment() {
    vec2 cloud_uv = (UV - vec2(0.5)) / CLOUD_ZOOM + vec2(0.5);
    vec4 mist = texture(TEXTURE, cloud_uv);
    if (reduced_flash) mist.rgb *= vec3(0.32,0.30,0.28);
    float waviness = sin(UV.y * 19.0) * 0.018 + sin(UV.y * 43.0 + UV.x * 8.0) * 0.008;
    float edge = mix(1.10, -0.10, coverage);
    float mask = smoothstep(edge - 0.06, edge + 0.06, UV.x + waviness);
    if (uncover) mask = 1.0 - mask;
    if (reduced_motion) mask = uncover ? 1.0 - coverage : coverage;
    // 云贴图带透明边缘：按云朵形状显示，并把淡边抬实，避免屏幕四周露缝
    float cloud_alpha = reduced_motion ? 1.0 : smoothstep(0.0, 0.12, mist.a);
    COLOR = vec4(mist.rgb, mask * cloud_alpha);
}
