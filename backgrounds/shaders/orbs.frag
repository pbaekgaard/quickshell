#version 440

// Raymarched smooth-union metaballs. Sixteen drifting spheres melt into
// each other; lighting comes from a single fixed direction and the
// palette ramps paper -> ink -> accent -> seal so theme swaps re-tint.

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

float opSmoothUnion(float d1, float d2, float k) {
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

float map(vec3 p) {
    float d = 2.0;
    for (int i = 0; i < 16; i++) {
        float fi = float(i);
        float t = iTime * (fract(fi * 412.531 + 0.513) - 0.5) * 2.0;
        d = opSmoothUnion(
            sdSphere(
                p + sin(t + fi * vec3(52.5126, 64.62744, 632.25)) * vec3(2.0, 2.0, 0.8),
                mix(0.5, 1.0, fract(fi * 412.531 + 0.5124))
            ),
            d,
            0.4
        );
    }
    return d;
}

vec3 calcNormal(in vec3 p) {
    const float h = 1e-5;
    const vec2 k = vec2(1.0, -1.0);
    return normalize(
        k.xyy * map(p + k.xyy * h) +
        k.yyx * map(p + k.yyx * h) +
        k.yxy * map(p + k.yxy * h) +
        k.xxx * map(p + k.xxx * h)
    );
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 fragCoord = uv * iResolution;

    // Screen modelled as a 6 m x 6 m plane; ray walks toward -Z.
    vec3 rayOri = vec3((uv - 0.5) * vec2(iResolution.x / max(iResolution.y, 1.0), 1.0) * 6.0, 3.0);
    vec3 rayDir = vec3(0.0, 0.0, -1.0);

    float depth = 0.0;
    vec3 p = rayOri;
    for (int i = 0; i < 64; i++) {
        p = rayOri + rayDir * depth;
        float dist = map(p);
        depth += dist;
        if (dist < 1e-6) break;
    }
    depth = min(6.0, depth);

    vec3 n = calcNormal(p);
    float b = max(0.0, dot(n, vec3(0.577)));

    // Palette ramp keyed off lighting + a slow temporal wobble. Replaces
    // the original rainbow cos() so the look survives theme reloads.
    float warp = 0.5 + 0.5 * sin(iTime * 0.4 + uv.x * 1.7 + uv.y * 1.3);
    vec3 base = mix(colPaper.rgb, colAccent.rgb, 0.10);
    vec3 mid  = mix(colPaper.rgb, colAccent.rgb, 0.75);
    vec3 hot  = mix(colPaper.rgb, colSeal.rgb,   0.85);

    vec3 col = mix(base, mid, smoothstep(0.10, 0.65, b));
    col = mix(col, hot, smoothstep(0.55, 1.05, b + warp * 0.25));
    col *= 0.85 + b * 0.35;

    // Depth fog pulls far points back toward paper so the blob reads
    // against any backdrop.
    float fog = exp(-depth * 0.15);
    col = mix(colPaper.rgb, col, fog);

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
