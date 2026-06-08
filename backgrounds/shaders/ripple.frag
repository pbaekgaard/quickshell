#version 440

// Concentric ripples from two wandering centres. Brighter peaks, more
// visible interference where the two patterns cross.

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

void main() {
    vec2 uv = qt_TexCoord0;
    uv.x *= iResolution.x / max(iResolution.y, 1.0);
    float t = iTime;

    vec2 c1 = vec2(0.50 + 0.30 * sin(t * 0.14),
                   0.55 + 0.25 * cos(t * 0.11));
    vec2 c2 = vec2(0.50 + 0.36 * cos(t * 0.09 + 1.7),
                   0.45 + 0.32 * sin(t * 0.13 + 0.4));

    float r1 = length(uv - c1);
    float r2 = length(uv - c2);

    float w1 = sin(r1 * 16.0 - t * 1.1) * 0.5 + 0.5;
    float w2 = sin(r2 * 13.0 - t * 0.9) * 0.5 + 0.5;
    float w = w1 * w2;        // interference: bright only where peaks line up
    float wMix = (w1 + w2) * 0.5;

    vec3 col = colPaper.rgb;
    col = mix(col, colAccent.rgb, wMix * 0.55);
    col = mix(col, colSeal.rgb,   w * 0.55);
    col = mix(col, colInk.rgb,    (1.0 - wMix) * 0.10);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
