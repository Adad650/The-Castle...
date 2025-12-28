shader_type canvas_item;

// --- GODOT 4 COMPATIBILITY ---
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// --- SETTINGS ---
uniform float range : hint_range(0.0, 0.1) = 0.05; // Moved this UP so it works!
uniform float noise_quality : hint_range(0.0, 300.0) = 250.0;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.0088;
uniform float offset_intensity : hint_range(0.0, 0.1) = 0.03;
uniform float color_bleeding : hint_range(0.0, 1.0) = 0.5;

// --- FUNCTIONS ---
// Generates random noise
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

// Generates vertical noise/shake lines
float vertical_bar(float pos, float uv_y, float offset){
    float edge0 = (pos - range);
    float edge1 = (pos + range);
    float x = smoothstep(edge0, pos, uv_y) * offset;
    x -= smoothstep(pos, edge1, uv_y) * offset;
    return x;
}

void fragment(){
    vec2 uv = SCREEN_UV;
    
    // 1. Vertical Shake / Jitter
    // We create a scrolling vertical bar effect for "tape wobble"
    for (float i = 0.0; i < 0.71; i += 0.1313) {
        float d = mod(TIME * i, 1.7);
        float o = sin(1.0 - tan(TIME * 0.24 * i));
        o *= offset_intensity;
        uv.x += vertical_bar(d, uv.y, o);
    }
    
    // 2. Chromatic Aberration (Splitting RGB)
    float r = texture(SCREEN_TEXTURE, uv + vec2(offset_intensity, 0.0)).r;
    float g = texture(SCREEN_TEXTURE, uv).g;
    float b = texture(SCREEN_TEXTURE, uv - vec2(offset_intensity, 0.0)).b;
    
    // 3. Noise / Grain
    float noise = rand(uv * vec2(TIME, TIME)) * noise_intensity;
    
    // 4. Scanlines
    float scanline = sin(uv.y * noise_quality * 5.0 + TIME * 10.0);
    scanline = smoothstep(0.4, 0.5, scanline);
    
    // Combine
    vec3 color = vec3(r, g, b);
    color += noise;
    color -= scanline * 0.02; // Subtle darkening

    COLOR = vec4(color, 1.0);
}