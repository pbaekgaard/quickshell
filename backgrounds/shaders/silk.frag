#version 440

// Silken folds — anisotropic fBm with sharper ridge contrast, two-tone
// banding so the folds catch and lose "light" as they bend.

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
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.55;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.04;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    uv.x *= iResolution.x / max(iResolution.y, 1.0);
    float t = iTime;

    float a = t * 0.05;
    mat2 r = mat2(cos(a), -sin(a), sin(a), cos(a));
    mat2 s = mat2(5.0, 0.0, 0.0, 0.6);
    vec2 p = s * r * (uv - 0.5) + vec2(t * 0.18, 0.0);

    float f = fbm(p);
    float ridge = 1.0 - abs(0.5 - f) * 2.0;
    float lit = smoothstep(0.55, 0.95, f);

    vec3 col = colPaper.rgb;
    col = mix(col, colAccent.rgb, lit * 0.55);
    col = mix(col, colSeal.rgb,   ridge * 0.45);
    col = mix(col, colInk.rgb,    (1.0 - ridge) * 0.08);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
