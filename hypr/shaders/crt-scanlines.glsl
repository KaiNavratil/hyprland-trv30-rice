#version 300 es
precision mediump float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pixColor = texture(tex, v_texcoord);
    
    // Subtle scanline effect
    // Intensity is kept low (0.04) so it's always-on and not distracting
    float scanline = sin(v_texcoord.y * 800.0 * 3.14159) * 0.04 + 1.0;
    
    pixColor.rgb *= scanline;
    
    fragColor = pixColor;
}
