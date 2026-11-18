shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float scene_energy = 1.0;
uniform float flash_limit = 1.0;
void fragment() {
    // Local ribbons and particle diamonds only: no screen copy or bloom buffer.
    COLOR.rgb *= scene_energy * flash_limit;
}
