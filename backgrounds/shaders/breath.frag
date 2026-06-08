#version 440

// Strong radial halo with a colour-shifting core. The centre breathes
// in/out and slowly drifts; outer field uses ink so the contrast with
// the bright halo reads clearly.

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

    vec2 c = vec2(0.5 + 0.10 * sin(t * 0.13),
                  0.5 + 0.10 * cos(t * 0.11));
    float r = length(uv - c);

    float radius = 0.42 + 0.10 * sin(t * 0.6);
    float core = smoothstep(radius * 0.45, 0.0, r);
    float halo = smoothstep(radius, radius * 0.55, r);
    float outer = 1.0 - smoothstep(radius * 1.4, radius * 0.95, r);

    vec3 col = mix(colPaper.rgb, colAccent.rgb, 0.08);
    col = mix(col, colAccent.rgb, halo * 0.65);
    col = mix(col, colSeal.rgb,   core * 0.75);
    col = mix(col, mix(colPaper.rgb, colInk.rgb, 0.20), outer * 0.30);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
