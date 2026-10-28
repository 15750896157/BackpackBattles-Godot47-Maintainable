shader_type canvas_item;

uniform sampler2D noise : repeat_enable, filter_linear;

void fragment() {
	float noiseVal = texture(noise, UV).r;
	vec4 tex = texture(TEXTURE, UV);
	float alpha = COLOR.a;
	if (alpha < noiseVal) {
		COLOR.a = 0.0;
	}
	COLOR *= tex;
}