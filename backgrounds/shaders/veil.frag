#version 440

// Three coloured veils crossing — each band uses a stronger tint and
// higher alpha than the original subtle version, so the layering is
// actually readable.

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

float band(vec2 uv, float speedY, float speedX, float freqY, float freqX, float t) {
    float y = uv.y * freqY + speedY * t;
    float x = uv.x * freqX + speedX * t;
    return 0.5 + 0.5 * sin(y * 6.2831 + sin(x * 6.2831) * 0.9);
}

void main() {
    vec2 uv = qt_TexCoord0;
    uv.x *= iResolution.x / max(iResolution.y, 1.0);
    float t = iTime;

    float b1 = band(uv, 0.030, 0.012, 0.9, 0.5, t);
    float b2 = band(uv, -0.022, 0.018, 1.4, 0.7, t + 11.0);
    float b3 = band(uv, 0.015, -0.026, 2.1, 1.1, t + 23.0);

    vec3 col = colPaper.rgb;
    col = mix(col, mix(colPaper.rgb, colAccent.rgb, 0.35), b1 * 0.75);
    col = mix(col, mix(colPaper.rgb, colSeal.rgb,   0.50), b2 * 0.80);
    col = mix(col, mix(colPaper.rgb, colInk.rgb,    0.18), b3 * 0.55);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
