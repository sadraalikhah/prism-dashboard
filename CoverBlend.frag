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
    cover = mix(cover, hue * 0.55, 0.08 + bottom * 0.14);
    cover = mix(cover, baseColor.rgb, 0.18 * top + 0.48 * bottom);

    float radius = min(cardRadius, min(cardSize.x, cardSize.y) * 0.5);
    vec2 corner = abs(uv * cardSize - cardSize * 0.5)
                - (cardSize * 0.5 - vec2(radius));
    float distanceToCard = length(max(corner, 0.0))
                         + min(max(corner.x, corner.y), 0.0) - radius;
    float alpha = (1.0 - smoothstep(-1.0, 1.0, distanceToCard)) * qt_Opacity;
    fragColor = vec4(cover * alpha, alpha);
}
