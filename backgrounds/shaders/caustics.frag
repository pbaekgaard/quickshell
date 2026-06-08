#version 440

// Water-surface caustics with real punch — the bright branching lines
// should be visible against any theme paper.

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
    float t = iTime * 0.30;

    vec2 p = uv * 4.5;
    vec2 i = p;
    float c = 1.0;
    for (int n = 0; n < 5; n++) {
        float fn = float(n) + 1.0;
        i = p + vec2(cos(t / fn + i.x), sin(t / fn - i.y));
        c += 1.0 / length(vec2(p.x / (sin(i.x + t) * 7.0),
                               p.y / (cos(i.y + t) * 7.0)));
    }
    c /= 5.0;
    c = 1.17 - pow(c, 1.4);
    float caustic = clamp(pow(abs(c), 5.0), 0.0, 1.0);

    vec3 col = mix(colPaper.rgb, mix(colPaper.rgb, colInk.rgb, 0.25), 0.4);
    col = mix(col, colAccent.rgb, caustic * 0.75);
    col = mix(col, colSeal.rgb,   caustic * caustic * 0.6);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
