#version 300 es
precision mediump float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    // Balanced 3500K warm twilight (reduces harsh blue spikes)
    pix.r = min(1.0, pix.r * 1.05);
    pix.g = min(1.0, pix.g * 0.95);
    pix.b = pix.b * 0.75;
    fragColor = pix;
}
