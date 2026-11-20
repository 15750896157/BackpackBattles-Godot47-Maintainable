shader_type canvas_item;
global uniform float bb_shader_time;

uniform sampler2D distortionTexture : repeat_enable, filter_linear;
uniform float scale : hint_range(0.001, 3) = 1.0;
uniform float speed : hint_range(0.05, 0.5) = 0.3;
uniform float strength : hint_range(0.05, 1.0) = 0.1;
uniform vec2 distortDir = vec2(1, 1);
varying float instanceOffset;

void vertex() {
	//lifetime = INSTANCE_CUSTOM.y;
	instanceOffset = INSTANCE_CUSTOM.z;
}

void fragment() {
	float distortion = texture(distortionTexture, 
		UV * scale + bb_shader_time * speed + instanceOffset).r - 0.5;
	
	//vec2 uv = (UV * 2.0 + vec2(-0.5)) + distortion * strength;
	vec2 uv = UV + distortDir * distortion * strength;
	COLOR = texture(TEXTURE, uv) * COLOR;
}