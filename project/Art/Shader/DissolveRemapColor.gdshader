shader_type canvas_item;
varying vec4 legacy_modulate;

//uniform float dissolveState : hint_range(0.0, 1.0);
uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec2 scale = vec2(1, 1);
uniform sampler2D gradient : repeat_disable, filter_linear;
uniform bool use2ndGradient = false;
uniform sampler2D gradient2 : repeat_disable, filter_linear;
uniform float xPos;

const float blendWidth = 0.05;

void fragment(){
	COLOR = vec4(1.0);
	COLOR *= texture(TEXTURE, UV);
	COLOR.a *= step(texture(noise, SCREEN_UV * scale).r, legacy_modulate.a);
	
	vec3 gradCol1 = texture(gradient, vec2(COLOR.r)).rgb;
	if (use2ndGradient) {
		vec3 gradCol2 = texture(gradient2, vec2(COLOR.r)).rgb;
		float blend = smoothstep(xPos - blendWidth, xPos + blendWidth, SCREEN_UV.x);
		COLOR.rgb = mix(gradCol1, gradCol2, blend);
	} else {
		COLOR.rgb = gradCol1;
	}
	COLOR.rgb *= legacy_modulate.r;
}
void vertex() { legacy_modulate = COLOR; }
