#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float cardRadius;
    vec2 cardSize;
    vec4 primaryColor;
    vec4 secondaryColor;
    vec4 baseColor;
};
layout(binding = 1) uniform sampler2D artwork;

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 cover = texture(artwork, uv).rgb;
    float top = 1.0 - smoothstep(0.02, 0.24, uv.y);
    float bottom = smoothstep(0.35, 1.0, uv.y);
    vec3 hue = mix(secondaryColor.rgb, primaryColor.rgb,
                   smoothstep(0.0, 1.0, uv.x + uv.y * 0.22));
    cover = mix(cover, hue * 0.55, 0.03 + bottom * 0.08);
    cover = mix(cover, baseColor.rgb, 0.12 * top + 0.30 * bottom);

    vec2 a = (uv - vec2(-0.10, 0.18)) * vec2(1.4, 1.1);
    vec2 b = (uv - vec2(1.10, 0.82)) * vec2(1.4, 1.1);
    float glowA = exp(-dot(a, a) * 2.2);
    float glowB = exp(-dot(b, b) * 2.2);
    cover = mix(cover, primaryColor.rgb * 0.82, glowA * 0.20);
    cover = mix(cover, secondaryColor.rgb * 0.82, glowB * 0.18);

    float radius = min(cardRadius, min(cardSize.x, cardSize.y) * 0.5);
    vec2 corner = abs(uv * cardSize - cardSize * 0.5)
                - (cardSize * 0.5 - vec2(radius));
    float distanceToCard = length(max(corner, 0.0))
                         + min(max(corner.x, corner.y), 0.0) - radius;
    float alpha = (1.0 - smoothstep(-1.0, 1.0, distanceToCard)) * qt_Opacity;
    fragColor = vec4(cover * alpha, alpha);
}
