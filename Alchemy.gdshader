shader_type canvas_item;

// ----------------------
// EXTREMELY BOLD OOZE-CENTRIC PURPLE SCARY DUNGEON VIBE - SMALLER, DARKER, REALISTIC OOZE, NO STRONG LIGHT, SLOWER RANDOM FOG
// ----------------------
uniform vec3 base_color : source_color = vec3(0.05,0.03,0.05);
uniform vec3 vein_color : source_color = vec3(0.7,0.35,1.0);
uniform vec3 fog_color : source_color = vec3(0.15,0.08,0.12);
uniform vec3 ooze_color : source_color = vec3(0.3,0.15,0.4); // Darker purple ooze
uniform float vein_strength : hint_range(0.0,1.0) = 0.8;
uniform float vein_thickness : hint_range(0.001,0.02) = 0.012;
uniform float fog_density : hint_range(0.0,1.0) = 0.7;
uniform float ooze_density : hint_range(0.0,1.0) = 0.98;
uniform float flow_speed : hint_range(0.01,0.2) = 0.1;
uniform float distort_amp : hint_range(0.0,0.1) = 0.045;
uniform float ooze_thickness : hint_range(0.005,0.05) = 0.02; // Smaller ooze
uniform float blob_count : hint_range(10.0,50.0) = 25.0;
uniform float blob_speed : hint_range(0.001,0.03) = 0.01;
uniform float ooze_shine : hint_range(0.0,3.0) = 0.5; // Minimal shine
uniform float crack_density : hint_range(0.0,1.0) = 0.7;
uniform float ooze_layers : hint_range(1.0,5.0) = 4.0;

// Helpers
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.45);
    return fract(p.x * p.y);
}
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    p *= 1.6;
    for (int i = 0; i < 8; i++) {
        v += a * noise(p);
        p *= 2.02;
        a *= 0.47;
    }
    return v;
}

// Organic distortion for oozing movement
vec2 ooze_distort(vec2 uv, float t) {
    float phase_x = uv.x + t * flow_speed * 0.8;
    float phase_y = uv.y - t * flow_speed * 1.2;
    float distort_x = (fbm(vec2(phase_y * 5.0, uv.y * 3.0)) - 0.5) * distort_amp * 1.5;
    float distort_y = (fbm(vec2(phase_x * 4.0, uv.x * 2.5 + 50.0)) - 0.5) * distort_amp;
    return vec2(distort_x, distort_y);
}

// Twisted veins with ooze influence
float veins(vec2 uv, float t) {
    vec2 p = uv * vec2(7.0, 9.0) + ooze_distort(uv, t) * 0.6;
    float n1 = fbm(p + vec2(t * 0.04, t * 0.06));
    float n2 = fbm(p * 2.0 + vec2(t * 0.05, -t * 0.03)) * 0.7;
    float vein_core = abs(n1 + n2 - 0.7) * 1.2;
    vein_core = smoothstep(vein_thickness * 1.4, 0.0, vein_core);
    float branches = smoothstep(vein_thickness * 0.8, 0.0, fbm(p * 4.0 + t * 0.03)) * 0.5;
    return (vein_core + branches) * vein_strength;
}

// Organic cracks seeping ooze
float cracks(vec2 uv) {
    vec2 p = uv * vec2(12.0, 15.0);
    float c = fbm(p * 1.3 + sin(p * 0.5));
    c = pow(1.0 - abs(c * 2.0 - 1.0), 5.0);
    return c * crack_density;
}

// Smaller organic ooze blobs with lateral movement
float ooze_blob(vec2 uv, float t, float id) {
    vec2 seed = vec2(id * 41.37, id * 72.91);
    float phase = fract(t * blob_speed + hash21(seed));
    vec2 bpos = vec2(phase * 1.4 - 0.2, hash21(seed + vec2(2.3)));
    float curve_freq = 5.0 + hash21(seed + vec2(5.0)) * 8.0;
    float curve_amp = 0.25 + hash21(seed + vec2(8.0)) * 0.2;
    bpos.y += sin(phase * 3.14159 * curve_freq + hash21(seed + vec2(11.0)) * 6.283) * curve_amp;
    if (bpos.x > 1.2) bpos.x -= 1.2;
    float bsize = ooze_thickness * (2.0 + hash21(seed + vec2(14.0)) * 3.0); // Smaller sizes
    float bd = length(uv - bpos);
    float core = smoothstep(bsize * 0.8, 0.0, bd);
    float halo = exp(-bd / (bsize * 0.7)) * 0.3; // Softer halo
    return core + halo * 0.4; // Reduced intensity
}

void fragment() {
    vec2 uv = SCREEN_UV;
    float t = TIME;
    vec3 col = base_color;
    
    // Bold oozing distortion on walls
    vec2 warped_uv = uv + ooze_distort(uv, t) * 1.2;
    
    // Ultra-detailed organic stone texture
    vec2 stone_p = warped_uv * vec2(8.5, 10.5);
    float stone = fbm(stone_p);
    float stone_detail = fbm(stone_p * 7.0) * 0.25;
    float stone_coarse = fbm(stone_p * 0.7) * 0.45;
    col *= 0.4 + (stone + stone_detail + stone_coarse) * 0.6;
    
    // Deep ooze-seeping cracks
    float c = cracks(warped_uv);
    col = mix(col, ooze_color * 0.5, c * 0.7);
    col -= vec3(0.14, 0.07, 0.16) * c * 0.9;
    
    // Integrated bold veins in ooze
    float v = veins(warped_uv, t);
    col = mix(col, vein_color * 0.85, v);
    col += ooze_color * pow(v, 2.5) * 0.6; // Reduced glow
    
    // Smaller ooze pool at bottom with subtle waves
    float pool = pow(smoothstep(0.0, 0.3, 1.0 - uv.y), 1.2) * 0.65;
    float pool_waves = sin(uv.x * 15.0 + t * 2.0) * 0.05 + fbm(vec2(uv.x * 10.0, t * 0.5)) * 0.1;
    pool += pool_waves * 0.2;
    col = mix(col, ooze_color * 0.8, pool);
    
    // Multi-layered organic flowing ooze (lateral and diagonal emphasis)
    float ooze_flow_total = 0.0;
    for (float i = 0.0; i < ooze_layers; i += 1.0) {
        float layer_off = i * 0.3;
        vec2 flow_uv = vec2((uv.x + t * flow_speed * (0.6 + i * 0.2)) * (8.0 + i * 2.0), uv.y * (6.0 + i * 1.5) + sin(uv.x * 5.0 + t * 0.3 + layer_off) * 0.2);
        float ooze_flow = fbm(flow_uv + ooze_distort(uv, t + layer_off)) * 0.8 + 0.2;
        ooze_flow = smoothstep(0.3 - i * 0.05, 0.8 + i * 0.05, ooze_flow);
        ooze_flow_total += ooze_flow / ooze_layers;
    }
    col = mix(col, ooze_color * 1.2, ooze_flow_total * 0.5);
    
    // Bold lateral sliding blobs (horizontal emphasis)
    float blob_total = 0.0;
    for (float i = 0.0; i < blob_count; i += 1.0) {
        blob_total += ooze_blob(uv, t, i);
    }
    blob_total = min(blob_total * 1.8, 1.0);
    col = mix(col, ooze_color * 1.4, blob_total * ooze_density);
    
    // Minimal ooze shine without strong light
    float ooze_total = (ooze_flow_total + blob_total + pool) * 0.5;
    vec2 vdir = normalize(uv - 0.5);
    float fresnel = pow(1.0 - abs(dot(vdir, vec2(1.0, 0.0))), 3.0);
    col += ooze_color * 0.5 * ooze_total * fresnel * ooze_shine; // Reduced
    col += ooze_color * pow(ooze_total, 2.0) * 0.4; // Reduced glow
    
    // Subtle bubbling in ooze for realism
    float bubbles = fbm(uv * 30.0 + vec2(t * 0.5, t * 0.2)) * ooze_total * 1.8;
    bubbles = smoothstep(0.7, 1.0, bubbles) * 0.15; // Reduced intensity
    col += ooze_color * 0.8 * bubbles; // Darker bubbles
    
    // Thick swirling fog with slower, random movement
    float fog_rand_x = noise(vec2(t * 0.05, 0.0)) * 0.1;
    float fog_rand_y = noise(vec2(t * 0.05 + 10.0, 0.0)) * 0.1;
    vec2 fog_p = uv * vec2(2.1, 2.6) + vec2(t * 0.01 + fog_rand_x, -t * 0.015 + fog_rand_y) + ooze_distort(uv, t) * 0.4;
    float f = fbm(fog_p) * fog_density * (0.8 + sin(t * 0.2) * 0.2);
    col = mix(col, fog_color, f);
    
    // Intense vignette
    vec2 vpos = uv - 0.5;
    float vig = 1.0 - dot(vpos, vpos) * 2.5;
    vig = pow(vig, 2.0);
    col *= vig;
    
    // Bold pulse
    float pulse = 0.7 + sin(t * 0.5) * 0.2;
    col *= pulse;
    
    COLOR = vec4(col, 1.0);
}