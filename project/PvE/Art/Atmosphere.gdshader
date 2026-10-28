shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 source_position = vec2(0.5, 0.12);
uniform vec4 warmth : source_color = vec4(1.0, 0.86, 0.64, 1.0);
uniform float darkness = 0.07;
uniform float glow = 0.04;
void fragment() {
    vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
    vec2 offset = (SCREEN_UV - source_position) * vec2(1.0, 0.5625);
    float light = exp(-dot(offset, offset) * 6.0);
    float edge = smoothstep(0.18, 0.82, distance(SCREEN_UV, vec2(0.5)));
    float shade = darkness*(1.0-light)+edge*darkness*0.35;
    scene *= mix(vec3(1.0),vec3(0.91,0.95,1.0),shade)*(1.0-shade);
    scene += warmth.rgb * light * glow;
    scene = max(vec3(0.0),(scene-vec3(0.5))*1.035+vec3(0.5));
    COLOR = vec4(scene, 1.0);
}
