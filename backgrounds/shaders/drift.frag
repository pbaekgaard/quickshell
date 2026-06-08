#version 440

// Rotating-axis gradient across three theme colours. Visible motion
// with clear colour stops rather than a near-flat tint.

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
    vec2 p = uv - 0.5;
    p.x *= iResolution.x / max(iResolution.y, 1.0);

    float angle = iTime * 0.06;
    vec2 dir = vec2(cos(angle), sin(angle));
    float v = dot(p, dir) * 1.1 + 0.5
            + 0.12 * sin(iTime * 0.18 + dot(p, dir.yx) * 4.0);
    v = clamp(v, 0.0, 1.0);

    vec3 a = mix(colPaper.rgb, colAccent.rgb, 0.12);
    vec3 b = mix(colPaper.rgb, colAccent.rgb, 0.45);
    vec3 c = mix(colPaper.rgb, colSeal.rgb, 0.45);

    vec3 col = mix(a, b, smoothstep(0.05, 0.55, v));
    col = mix(col, c, smoothstep(0.50, 0.95, v));

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
