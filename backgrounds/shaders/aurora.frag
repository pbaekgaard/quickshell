#version 440

// Aurora curtains with real intensity — each curtain core glows
// brightly, the tails fade through accent into seal, against a darker
// ink-tinted sky.

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

float curtain(vec2 uv, float cx, float width, float speed, float phase) {
    float drift = cx + sin(uv.y * 2.7 + speed + phase) * 0.10
                     + sin(uv.y * 5.7 + speed * 1.4) * 0.04;
    float dx = abs(uv.x - drift);
    float falloff = exp(-pow(dx / width, 2.0));
    float vShape = smoothstep(0.02, 0.40, uv.y) * (1.0 - smoothstep(0.60, 1.0, uv.y) * 0.9);
    return falloff * vShape;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float aspect = iResolution.x / max(iResolution.y, 1.0);
    vec2 wide = vec2(uv.x * aspect, uv.y);
    float t = iTime * 0.35;

    float c1 = curtain(wide, aspect * 0.28, 0.12, t,         0.0);
    float c2 = curtain(wide, aspect * 0.52, 0.16, t * 0.7,   2.1);
    float c3 = curtain(wide, aspect * 0.78, 0.10, t * 1.3,   4.4);

    // Sky base: keep dark so the curtains glow against deep night.
    vec3 sky = mix(colPaper.rgb, colAccent.rgb, 0.05 + 0.12 * (1.0 - uv.y));
    vec3 col = sky;

    col = mix(col, colAccent.rgb, c1 * 0.85);
    col = mix(col, colSeal.rgb,   c2 * 0.70);
    col = mix(col, mix(colAccent.rgb, colInk.rgb, 0.20), c3 * 0.60);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
