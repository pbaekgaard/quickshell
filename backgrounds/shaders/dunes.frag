#version 440

// Sand ridges with sun and shadow faces. Sharper highlight band, real
// shadow side using ink — reads as a 3D landscape rather than flat
// noise.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
    vec4 colPaper;
    vec4 colInk;
    vec4 colAccent;
    vec4 colSeal;
};

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i),               hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0,1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void main() {
    vec2 uv = qt_TexCoord0;
    uv.x *= iResolution.x / max(iResolution.y, 1.0);
    float t = iTime * 0.08;

    vec2 p1 = vec2(uv.x * 1.5 + t, uv.y * 7.0);
    vec2 p2 = vec2(uv.x * 0.7 + t * 0.5, uv.y * 11.0 + sin(uv.x * 3.5) * 0.7);

    float h = noise(p1) * 0.65 + noise(p2) * 0.35;

    // Approximate slope by sampling neighbour to get a lighting cue.
    float hNext = noise(vec2(p1.x, p1.y + 0.3)) * 0.65
                + noise(vec2(p2.x, p2.y + 0.3)) * 0.35;
    float slope = hNext - h;

    float lit = smoothstep(0.0, 0.20, slope);
    float shadow = smoothstep(0.0, 0.20, -slope);

    vec3 col = mix(colPaper.rgb, colSeal.rgb, 0.22);
    col = mix(col, colAccent.rgb, lit * 0.55);
    col = mix(col, colPaper.rgb,  shadow * 0.65);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
