shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D painting : source_color, filter_nearest, repeat_disable;
uniform sampler2D silhouette : filter_nearest, repeat_disable;
uniform bool masked = false;
uniform bool effects_enabled = true;
void fragment() {
    vec4 art = texture(painting, UV);
    float cyan = smoothstep(0.48,0.74,min(art.g,art.b)) * (1.0-smoothstep(0.4,0.66,art.r));
    float pulse = effects_enabled ? (sin(TIME*1.4+UV.x*9.0+UV.y*12.0)*0.5+0.5)*0.045 : 0.0;
    ALBEDO = art.rgb * (1.0+cyan*pulse);
    ALPHA = masked ? texture(silhouette,UV).r : 1.0;
    ALPHA_SCISSOR_THRESHOLD = 0.5;
}
