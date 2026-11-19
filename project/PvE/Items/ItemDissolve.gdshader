shader_type canvas_item;

uniform float progress : hint_range(-1, 2) = 0.5;
uniform vec2 direction = vec2(0, 1);

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.rgb *= 1.0 + 0.5 * smoothstep(progress - 0.05, progress + 0.05, dot(UV, direction));
}
