shader_type canvas_item;
render_mode unshaded;
uniform float coverage : hint_range(0.0, 1.0) = 0.0;
uniform bool uncover = false;
uniform bool reduced_motion = false;
uniform bool reduced_flash = false;
void fragment() {
    vec4 mist = texture(TEXTURE, UV);
    if (reduced_flash) mist.rgb *= vec3(0.32,0.30,0.28);
    float waviness = sin(UV.y * 19.0) * 0.018 + sin(UV.y * 43.0 + UV.x * 8.0) * 0.008;
    float edge = mix(1.10, -0.10, coverage);
    float mask = smoothstep(edge - 0.06, edge + 0.06, UV.x + waviness);
    if (uncover) mask = 1.0 - mask;
    if (reduced_motion) mask = uncover ? 1.0 - coverage : coverage;
    COLOR = vec4(mist.rgb, mask);
}
