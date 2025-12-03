shader_type canvas_item;

uniform vec2 offset = vec2(0.0);
uniform float time_scale = 1.0;
uniform bool enabled = true;
uniform bool seamless_tiling = true;

// Multi-octave noise with rotation for seamless tiling
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractional Brownian Motion (fBm) - multi-octave noise
float fbm(vec2 p, int octaves, float persistence) {
    float total = 0.0;
    float frequency = 1.0;
    float amplitude = 1.0;
    float maxValue = 0.0;
    
    for(int i = 0; i < octaves; i++) {
        total += noise(p * frequency) * amplitude;
        maxValue += amplitude;
        amplitude *= persistence;
        frequency *= 2.0;
    }
    
    return total / maxValue;
}

// Domain warping for organic patterns
vec2 domainWarp(vec2 p) {
    vec2 q = vec2(
        fbm(p + vec2(0.0, 0.0), 2, 0.5), // Reduced from 3
        fbm(p + vec2(5.2, 1.3), 2, 0.5)  // Reduced from 3
    );
    
    vec2 r = vec2(
        fbm(p + 4.0 * q + vec2(1.7, 9.2), 2, 0.5), // Reduced from 3
        fbm(p + 4.0 * q + vec2(8.3, 2.8), 2, 0.5)  // Reduced from 3
    );
    
    return vec2(
        fbm(p + 4.0 * r, 2, 0.5), // Reduced from 3
        fbm(p + 4.0 * r + vec2(1.0, 1.0), 2, 0.5) // Reduced from 3
    );
}

void fragment() {
    vec2 uv = UV;
    if (seamless_tiling) {
        uv = UV + offset * 0.00005; // Apply offset for scrolling (scaled down)
    } else {
        // Non-seamless mode - use screen space coordinates
        uv = FRAGCOORD.xy / vec2(textureSize(TEXTURE, 0)) + offset * 0.00005;
    }
    
	float t = TIME * time_scale;
	
    vec3 finalColor;
    
	if (!enabled) {
		finalColor = vec3(0.0, 0.0, 0.0);
	} else {
		// Layer 1: Distant star field (high frequency)
		// Reduced octaves from 4 to 3
		float stars = fbm(uv * 8.0 + t * 0.01, 3, 0.4);
		stars = pow(stars, 8.0);
		vec3 starColor = vec3(1.0, 0.9, 0.8) * stars;
		
		// Layer 2: Nebula base (medium frequency with domain warp)
		// Reduced octaves from 6 to 4
		vec2 warpedUV = uv * 0.2 + domainWarp(uv * 0.1 + t * 0.005);
		float nebula = fbm(warpedUV, 4, 0.6);
		vec3 nebulaColor = mix(
			vec3(0.1, 0.05, 0.3),
			vec3(0.8, 0.3, 0.6),
			nebula
		);
		
		// Layer 3: Gas clouds (low frequency)
		// Reduced octaves from 5 to 3
		float clouds = fbm(uv * 0.1 + t * 0.002, 3, 0.7);
		vec3 cloudColor = mix(
			vec3(0.05, 0.02, 0.1),
			vec3(0.4, 0.1, 0.8),
			clouds * 0.5
		);
		
		// Layer 4: Dynamic energy fields
		// Reduced octaves from 3 to 2
		float energy = sin(uv.x * 3.0 + uv.y * 2.0 + t * 0.5) * 0.5 + 0.5;
		energy *= fbm(uv * 4.0 + t * 0.1, 2, 0.5);
		vec3 energyColor = vec3(0.2, 0.6, 1.0) * energy * 0.3;
		
		// Combine layers
		finalColor = nebulaColor;
		finalColor = mix(finalColor, cloudColor, clouds * 0.3);
		finalColor += starColor;
		finalColor += energyColor;
		
		// Add some color variation
		finalColor *= mix(vec3(1.0), vec3(1.0, 0.9, 0.7), fbm(uv * 0.5, 2, 0.5) * 0.3);
	}
    
    COLOR = vec4(finalColor, 1.0);
}
