shader_type canvas_item;

uniform vec4 beam_color : source_color = vec4(0.0, 0.8, 1.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed : hint_range(0.0, 10.0) = 3.0;
uniform float thickness : hint_range(0.0, 1.0) = 0.3;
uniform float oscillation : hint_range(0.0, 50.0) = 20.0;
uniform float noise_scale : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    float time = TIME * speed;
    
    // Create a scrolling noise effect
    float noise = sin(UV.x * oscillation + time) * 0.1;
    
    // Calculate distance from center (UV.y = 0.5)
    float dist = abs(UV.y - 0.5 + noise);
    
    // Core beam
    float core = smoothstep(thickness * 0.5, 0.0, dist);
    
    // Outer glow
    float glow = smoothstep(thickness * 2.0, 0.0, dist);
    
    // Pulse effect along the length
    float pulse = sin(UV.x * 10.0 - time * 2.0) * 0.5 + 0.5;
    
    // Combine colors
    vec4 final_color = mix(beam_color, core_color, core);
    final_color.a *= glow * (0.8 + 0.2 * pulse);
    
    COLOR = final_color;
}
