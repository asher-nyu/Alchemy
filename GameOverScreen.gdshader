shader_type canvas_item;

// Godot 4 screen texture hint
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// =====================================================
// GAME OVER – SOMBER PURPLE DUNGEON / LOST HOPE
// =====================================================

// ---------- Palette ----------
uniform vec4 stone_dark   : source_color = vec4(0.03, 0.01, 0.07, 1.0); // very deep violet
uniform vec4 stone_light  : source_color = vec4(0.15, 0.08, 0.25, 1.0); // muted lavender stone
uniform vec3 mist_color   : source_color = vec3(0.25, 0.15, 0.35);      // purple mist/fog
uniform vec3 rune_glow    : source_color = vec3(0.55, 0.35, 0.85);      // subdued magical glow
uniform vec3 ember_blue   : source_color = vec3(0.35, 0.55, 0.85);      // cold ethereal sparks

// ---------- Dungeon Stone Texture ----------
uniform float brick_count     : hint_range(2.0, 20.0) = 8.0;
uniform float seam_thickness  : hint_range(0.0005, 0.02) = 0.007;
uniform float crack_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float noise_strength  : hint_range(0.0, 3.0) = 1.0;

// ---------- Scene Mood ----------
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.85;
uniform float fog_amount        : hint_range(0.0, 1.0) = 0.4;
uniform float flicker_amount    : hint_range(0.0, 1.0) = 0.2;

// ---------- Magical Light ----------
uniform vec2  light_pos      = vec2(0.6, 0.75);
uniform float light_radius   : hint_range(0.1, 2.0) = 0.8;
uniform float light_strength : hint_range(0.0, 4.0) = 1.0;

// ---------- Chromatic / Glitch FX ----------
uniform float chroma_px       : hint_range(0.0, 8.0) = 1.8;
uniform float jitter_amount   : hint_range(0.0, 0.4) = 0.1;
uniform float slice_freq      : hint_range(50.0, 600.0) = 180.0;
uniform float glitch_speed    : hint_range(0.0, 10.0) = 1.5;
uniform float glitch_intensity: hint_range(0.0, 1.0) = 0.35;

// ---------- Helper Noise ----------
float hash21(vec2 p){
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.45);
    return fract(p.x * p.y);
}

float noise(vec2 p){
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

float fbm(vec2 p){
    float v = 0.0;
    float a = 0.5;
    for (int i=0; i<5; i++){
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

// ---------- Dungeon Surface ----------
vec3 stone_scene(vec2 uv){
    float t = TIME;
    uv += vec2(sin(t * 0.15), cos(t * 0.12)) * 0.008 * jitter_amount;

    // Brick pattern
    vec2 P = uv * vec2(10.0, brick_count);
    float row = floor(P.y);
    float offset = mod(row, 2.0) * 0.5;
    float seamX = abs(fract(P.x + offset) - 0.5);
    float seamY = abs(fract(P.y) - 0.5);
    float seam = smoothstep(0.48, 0.48 + seam_thickness, max(seamX, seamY));

    // Base stone
    float n = fbm(uv * 5.0);
    vec3 base = mix(stone_dark.rgb, stone_light.rgb, n * 0.8);
    base += rune_glow * pow(fbm(uv * 12.0 + vec2(t * 0.15)), 5.0) * 0.15;

    // Cracks
    float crack = smoothstep(0.7, 0.95, fbm(uv * 20.0));
    base = mix(base, base * 0.3, crack * crack_intensity);

    // Fog / mist
    float fog = fbm(uv * 3.0 + vec2(t * 0.05, -t * 0.03));
    base = mix(base, base + mist_color * 0.2, fog * fog_amount);

    // Light falloff
    float dist = distance(uv, light_pos);
    float L = pow(max(0.0, 1.0 - dist / light_radius), 2.5);
    float flicker = 1.0 + flicker_amount * sin(t * 4.0);
    base += (ember_blue * L * light_strength * flicker * 0.2);

    // Seams darker
    base *= 1.0 - seam * 0.35;

    return base;
}

// ---------- Final Composition ----------
void fragment(){
    vec2 uv = SCREEN_UV;
    float t = TIME;

    // Subtle slicing glitch
    float row = floor(uv.y * slice_freq);
    float gate = step(0.7, fract(sin((row + floor(t * glitch_speed)) * 12.9898) * 78.233));
    float offset = (hash21(vec2(row, floor(t * glitch_speed))) - 0.5) * 2.0;
    float jump = gate * offset * jitter_amount * glitch_intensity;

    vec2 px = SCREEN_PIXEL_SIZE * chroma_px;
    vec3 col_r = stone_scene(uv + vec2(jump, 0.0) + vec2(px.x, 0.0));
    vec3 col_g = stone_scene(uv + vec2(jump * 0.5, 0.0));
    vec3 col_b = stone_scene(uv - vec2(jump, 0.0) - vec2(px.x, 0.0));
    vec3 col = vec3(col_r.r, col_g.g, col_b.b);

    // Vignette
    vec2 v = uv - 0.5;
    float vig = 1.0 - dot(v, v) * 2.2;
    vig = clamp(mix(1.0, vig, vignette_strength), 0.0, 1.0);
    col *= vig;

    COLOR = vec4(col, 1.0);
}