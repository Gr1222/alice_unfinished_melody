shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
varying vec3 painted_color;
void vertex() {
    // The Blender FLOAT_COLOR attribute is linear; the Compatibility vertex
    // path needs its authored display palette restored before material lighting.
    painted_color = pow(max(COLOR.rgb,vec3(0.0)),vec3(1.0/2.2));
}
void fragment() {
    ALBEDO = painted_color;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
