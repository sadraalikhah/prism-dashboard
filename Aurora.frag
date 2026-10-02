#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
    float aspect;
    float waveSeed;
    vec2 hoverPosition;
    vec2 hoverVelocity;
    vec2 trailPosition;
    vec2 tailPosition;
    float hoverStrength;
    float cardRadius;
    vec2 cardSize;
    vec4 primaryColor;
    vec4 secondaryColor;
    vec4 lightColor;
};

float randomValue(vec2 seed) {
    return fract(sin(dot(seed, vec2(127.1, 311.7))) * 43758.5453);
}

float mergeBubbles(float a, float b, float softness) {
    float h = clamp(0.5 + 0.5 * (b - a) / softness, 0.0, 1.0);
    return mix(b, a, h) - softness * h * (1.0 - h);
}

void main() {
    vec2 uv = qt_TexCoord0;
    float t = phase;
    vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
    p += vec2(0.075 * sin(uv.y * 10.0 - t * 0.8) + 0.035 * cos(uv.x * 15.0 + t * 0.6),
              0.065 * cos(uv.x * 12.0 + t * 0.7));

    vec2 a = (p - vec2(-0.23 + 0.16 * sin(t * 0.43), -0.20 + 0.13 * cos(t * 0.51))) * vec2(3.8, 3.0);
    vec2 b = (p - vec2( 0.25 + 0.14 * cos(t * 0.37),  0.18 + 0.17 * sin(t * 0.46))) * vec2(3.2, 3.5);
    float bloomA = exp(-dot(a, a));
    float bloomB = exp(-dot(b, b));
    float waveA = sin(p.x * 16.0 + p.y * 7.0 + 2.0 * sin(p.y * 5.0 - t * 0.5) - t * 1.2);
    float waveB = sin(p.y * 13.0 - p.x * 6.0 + t * 0.8);
    float ribbon = 0.88 * exp(-3.2 * waveA * waveA);
    float ribbonB = 0.78 * exp(-2.8 * waveB * waveB);

    vec2 dotGrid = vec2(24.0, 40.0);
    vec2 gridPosition = uv * dotGrid;
    float dotSeed = randomValue(floor(gridPosition));
    vec2 cell = fract(gridPosition) - 0.5;
    vec2 circularCell = cell * vec2(aspect * dotGrid.y / dotGrid.x, 1.0);
    float groupEnergy = 0.0;
    const float waveLifetime = 36.0;
    for (int i = 0; i < 2; ++i) {
        float slot = float(i);
        float waveClock = t + slot * waveLifetime * 0.5;
        float age = mod(waveClock, waveLifetime) / waveLifetime;
        float generation = floor(waveClock / waveLifetime);
        float seed = waveSeed + generation * 2.0 + slot;
        vec2 origin = vec2(0.12) + 0.76 * vec2(
            randomValue(vec2(seed, 7.31)),
            randomValue(vec2(seed, 23.47))
        );
        vec2 waveDelta = vec2((uv.x - origin.x) * aspect, uv.y - origin.y);
        float distanceToOrigin = length(waveDelta);
        float radius = age * 0.15;
        float distanceFromFront = distanceToOrigin - radius;
        float front = exp(-distanceFromFront * distanceFromFront / 0.0016);
        float envelope = exp(-dot(waveDelta, waveDelta) / 0.0225);
        float fade = smoothstep(0.0, 0.16, age) * (1.0 - smoothstep(0.74, 1.0, age));
        groupEnergy = max(groupEnergy, envelope * (0.45 + 0.55 * front) * fade);
    }
    vec2 hoverDelta = (uv - hoverPosition) * vec2(aspect, 1.0);
    vec2 velocity = hoverVelocity * vec2(aspect, 1.0);
    float speed = length(velocity);
    vec2 direction = speed > 0.0001 ? velocity / speed : vec2(1.0, 0.0);
    float stretch = 1.0 + min(speed * 0.25, 0.75);
    vec2 bubble = vec2(dot(hoverDelta, direction) / stretch,
                       dot(hoverDelta, vec2(-direction.y, direction.x)) * sqrt(stretch));
    float angle = atan(bubble.y, bubble.x);
    float wobble = 0.003 * sin(angle * 3.0 + t * 2.2)
                 + min(speed * 0.003, 0.007) * sin(angle * 2.0 - t * 3.0);
    float bubbleDistance = length(bubble) - (0.105 + wobble);
    float trailSize = min(speed * 0.018, 0.025);
    float trailDistance = length((uv - trailPosition) * vec2(aspect, 1.0)) - (0.055 + trailSize);
    float tailDistance = length((uv - tailPosition) * vec2(aspect, 1.0)) - (0.028 + trailSize * 0.6);
    float liquidDistance = mergeBubbles(mergeBubbles(bubbleDistance, trailDistance, 0.045), tailDistance, 0.035);
    float hoverAura = (1.0 - smoothstep(-0.012, 0.018, liquidDistance)) * hoverStrength;
    float dotVisibility = max(smoothstep(0.02, 0.30, groupEnergy), hoverAura * 0.82);
    float dotSize = mix(0.045, 0.065, dotSeed);
    float dotDistance = length(circularCell);
    float core = 1.0 - smoothstep(dotSize * 0.5, dotSize, dotDistance);
    float halo = 1.0 - smoothstep(dotSize, dotSize + 0.035, dotDistance);
    float dots = (core * 0.95 + halo * 0.09) * mix(0.65, 1.0, dotSeed) * dotVisibility;
    float sweepY = uv.y - (0.47 + 0.16 * sin(uv.x * 8.0 - t * 0.12));
    float sweep = exp(-65.0 * sweepY * sweepY);

    vec3 color = mix(primaryColor.rgb, secondaryColor.rgb, 0.5 + 0.5 * sin(t * 0.35 + uv.y * 6.0));
    vec3 highlight = mix(lightColor.rgb, vec3(1.0), 0.65);
    color = mix(color, highlight, min(0.65, ribbon * 0.48 + ribbonB * 0.38));
    color = mix(color, highlight, min(0.90, dots * 0.85));
    float motion = clamp(0.07 + bloomA * 0.18 + bloomB * 0.16
                         + ribbon * 0.12 + ribbonB * 0.09, 0.0, 0.48);
    float dotPulse = mix(mix(0.48, 0.72, groupEnergy), 0.60, hoverAura);
    float alpha = min(0.76, motion + dots * (dotPulse + sweep * 0.06));
    float radius = min(cardRadius, min(cardSize.x, cardSize.y) * 0.5);
    vec2 corner = abs(uv * cardSize - cardSize * 0.5)
                - (cardSize * 0.5 - vec2(radius));
    float distanceToCard = length(max(corner, 0.0))
                         + min(max(corner.x, corner.y), 0.0) - radius;
    alpha *= (1.0 - smoothstep(-1.0, 1.0, distanceToCard)) * qt_Opacity;
    fragColor = vec4(color * alpha, alpha);
}
