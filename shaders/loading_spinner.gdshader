shader_type canvas_item;

uniform float speed : hint_range(0.1, 5.0) = 1.0;
uniform int dot_count : hint_range(3, 12) = 8;
uniform float radius : hint_range(0.1, 0.5) = 0.3;
uniform vec4 dot_color : source_color = vec4(0.2, 0.6, 1.0, 1.0);
uniform vec4 fade_color : source_color = vec4(0.2, 0.6, 1.0, 0.2);
uniform bool active = true;

void fragment() {
    if (!active) {
        discard;
    }
    
    vec2 center = vec2(0.5, 0.5);
    vec2 uv = UV - center;
    float dist = length(uv);
    
    // Create circular dots
    float angle = atan(uv.y, uv.x);
    float time = TIME * speed;
    
    // Calculate which dot this fragment belongs to
    float dot_angle = (angle + time) * float(dot_count) / (2.0 * PI);
    float dot_index = floor(dot_angle);
    float dot_progress = fract(dot_angle);
    
    // Create dot shape
    float dot_radius = 0.05;
    float current_angle = (dot_index * 2.0 * PI) / float(dot_count) - time;
    vec2 dot_pos = vec2(cos(current_angle), sin(current_angle)) * radius;
    float dot_dist = length(uv - dot_pos);
    
    // Fade dots based on their position in rotation
    float fade = 1.0 - (dot_progress * 0.8);
    
    // Draw dot with fade
    if (dot_dist < dot_radius) {
        float alpha = 1.0 - (dot_dist / dot_radius);
        COLOR = vec4(dot_color.rgb, dot_color.a * alpha * fade);
    } else {
        discard;
    }
}
