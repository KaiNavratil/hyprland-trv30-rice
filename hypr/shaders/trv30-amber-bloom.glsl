#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec2 uv = v_texcoord;
    
    // Subtle CRT glass faceplate curvature
    vec2 cc = uv - 0.5;
    float r2 = cc.x * cc.x + cc.y * cc.y;
    vec2 curved_uv = 0.5 + cc * (1.0 + 0.04 * r2);
    
    // Clip borders outside curvature
    if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0) {
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    // Subtle RGB phosphor chromatic separation (0.8px offset)
    float shift = 0.0007;
    float r = texture(tex, vec2(curved_uv.x + shift, curved_uv.y)).r;
    float g = texture(tex, curved_uv).g;
    float b = texture(tex, vec2(curved_uv.x - shift, curved_uv.y)).b;
    vec4 color = vec4(r, g, b, 1.0);
    
    // Subtle 80s CRT scanlines (5% raster modulation)
    float scanline = sin(curved_uv.y * 1080.0 * 3.14159) * 0.05 + 0.95;
    color.rgb *= scanline;
    
    // Analog glass vignette
    float dist = distance(curved_uv, vec2(0.5, 0.5));
    float vignette = 1.0 - (dist * dist * 0.32);
    color.rgb *= vignette;
    
    // Tokyo 80s TRV30 warm phosphor color grade
    color.rgb = mix(color.rgb, color.rgb * vec3(1.05, 0.98, 0.90), 0.45);

    fragColor = color;
}
