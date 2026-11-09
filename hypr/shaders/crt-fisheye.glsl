#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

float rand(in vec2 uv) {
    return fract(sin(uv.x * uv.y) * 423870.0);
}

void main() {
    vec2 uv = v_texcoord;
    
    // Intense barrel distortion (Fisheye)
    vec2 cc = uv - 0.5;
    float r2 = cc.x*cc.x + cc.y*cc.y;
    uv = 0.5 + cc * (1.0 + 0.4 * r2); // 0.4 multiplier for heavy warp
    
    float dist = distance(uv, vec2(0.5, 0.5));

    // Harsh boxy vignette (doesn't fade, creates a thick outline)
    // Cuts off the outer 12% of the screen entirely
    vec2 bl = step(0.12, uv);
    vec2 tr = step(0.12, 1.0 - uv);
    float box = 1.0 - (bl.x * bl.y * tr.x * tr.y);

    vec4 color = texture(tex, uv);

    // Deep orange tint filter
    color *= vec4(vec3(0.95, 0.65, 0.2) * (1.0-dist*0.5), 1.0);

    // Color noise
    color += vec4(mix(0.05, rand(uv), color.r), mix(0.05, rand(uv+0.12), color.g), mix(0., rand(uv+1.), color.b), 1.) * 0.75;

    // Heavy, extremely visible scanlines
    float scanline = sin(uv.y * 1500.0) * 0.4;
    color -= vec4(vec3(scanline), 0.0);

    // Apply the harsh black boxy vignette
    color -= vec4(vec3(box), 1.0);

    fragColor = color;
}
