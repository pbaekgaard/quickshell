#version 440

// Rising smoke wisps with proper opacity — clearly visible plumes
// against the paper backdrop, splaying as they climb.

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
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = mat2(1.6, 1.2, -1.2, 1.6) * p;
        a *= 0.5;
    }
    return v;
}

void main() {
    vec2 uv = qt_TexCoord0;
    uv.x *= iResolution.x / max(iResolution.y, 1.0);
    float t = iTime * 0.22;

    float warpAmt = (1.0 - uv.y) * 0.55;
    float warpX = sin(uv.y * 4.5 + t * 1.5) * warpAmt
                + fbm(vec2(uv.x * 3.5 + t, uv.y * 2.8)) * warpAmt * 0.9;

    vec2 p = vec2(uv.x + warpX, uv.y - t * 2.6);
    float f = fbm(p * vec2(4.0, 2.5));

    float density = pow(f, 1.5)
                  * smoothstep(0.02, 0.55, uv.y)
                  * (1.0 - smoothstep(0.75, 1.0, uv.y) * 0.6);

    vec3 col = colPaper.rgb;
    col = mix(col, mix(colPaper.rgb, colInk.rgb, 0.55), density * 0.55);
    col = mix(col, colAccent.rgb, density * density * 0.55);
    col = mix(col, colSeal.rgb,   pow(density, 4.0) * 0.5);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
