shader_type canvas_item;
uniform vec2 source_position = vec2(760.0, 270.0);
uniform vec4 light_tint : source_color = vec4(1.0, 0.91, 0.75, 1.0);
uniform float strength = 0.38;
uniform float emission_strength = 0.0;
uniform vec4 emission_tint : source_color = vec4(1.0);
uniform vec4 rarity_tint : source_color = vec4(1.0);
uniform bool reduced_flash = false;
varying vec2 world_position;
varying vec2 world_center;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy;
    vec2 center = VERTEX - (UV - vec2(0.5)) / TEXTURE_PIXEL_SIZE;
    world_center = (MODEL_MATRIX * vec4(center,0.0,1.0)).xy;
}
void fragment() {
    // CanvasItem already includes the texture in incoming COLOR.
    vec4 albedo = COLOR;
    vec2 to_light = normalize(source_position-world_center+vec2(0.01));
    float facing = dot(normalize(world_position-world_center+vec2(0.01)),to_light);
    // Derivatives use the existing color sample: no normal-map textures or
    // extra texture taps are needed for the painted surface's small relief.
    float height = dot(albedo.rgb,vec3(0.2126,0.7152,0.0722));
    vec2 slope = vec2(dFdx(height),dFdy(height));
    float bevel = clamp(dot(-slope,to_light)*1.8,-0.08,0.08);
    float sculpt = clamp(1.0 + facing * strength * 0.65 + bevel,0.74,1.30);
    albedo.rgb *= mix(vec3(1.0),light_tint.rgb,strength*0.6)*sculpt;
    if (emission_strength > 0.001) {
        vec2 px = TEXTURE_PIXEL_SIZE * 2.0;
        float inside = min(min(texture(TEXTURE, UV+vec2(px.x,0.0)).a,
                               texture(TEXTURE, UV-vec2(px.x,0.0)).a),
                           min(texture(TEXTURE, UV+vec2(0.0,px.y)).a,
                               texture(TEXTURE, UV-vec2(0.0,px.y)).a));
        float rim = clamp((albedo.a-inside)*2.0,0.0,1.0);
        float pulse = reduced_flash ? 0.85 : 0.85+0.15*sin(TIME*1.8);
        // Paint stays recognizable. Only bright details and a thin tier rim emit.
        albedo.rgb += emission_strength*pulse*(emission_tint.rgb*(0.12+height*height*0.65)+rarity_tint.rgb*rim);
    }
    COLOR = albedo;
}
