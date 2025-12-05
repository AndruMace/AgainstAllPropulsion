shader_type spatial;

uniform float time_scale = 1.0;
uniform float pulse_strength = 0.1;

void vertex() {
    float pulse = sin(TIME * time_scale + VERTEX.x + VERTEX.y) * pulse_strength;
    VERTEX += NORMAL * pulse;
}
