#version 300 es
precision mediump float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    // Deep 2400K vintage candlelight / heavy melatonin protection
    pix.r = min(1.0, pix.r * 1.08);
    pix.g = min(1.0, pix.g * 0.88);
    pix.b = pix.b * 0.52;
    fragColor = pix;
}
