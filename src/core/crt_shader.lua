-- Timothy Lottes CRT shader, adapted to LOVE2D 11.x.
--
-- The original (supplied in the design doc) was a raw GLSL fragment shader using
-- gl_FragCoord / gl_FragColor / texture2D(source,...). LOVE wraps fragment shaders
-- in an effect() entry point and exposes:
--    screen_coords  -> pixel coordinates (top-left origin)  [was gl_FragCoord.xy]
--    Texel(img, uv) -> texture sample                       [was texture2D]
-- so the coordinate/y-flip bookkeeping the original did by hand is unnecessary here.
--
-- Uniforms sent per-frame by video.lua:
--    trg_x/y/w/h  : the letterboxed rectangle the game is drawn into (window pixels)
--    source       : the 800x450 game canvas
-- (The original's scr_w/scr_h were only used to y-flip gl_FragCoord; LOVE's
--  screen_coords is already top-left origin, so they're dropped here.)
return [[
extern number trg_x;
extern number trg_y;
extern number trg_w;
extern number trg_h;
extern Image  source;

// Emulated input resolution (controls scanline / phosphor density AND how hard
// the source is downsampled). The classic Lottes value (256x144) crushes an
// 800x450 render into mush; matching the render resolution keeps text legible
// while the warp + shadow mask keep the CRT character.
vec2 res = vec2(800.0, 450.0);

// Hardness of scanline (-8 soft .. -16 medium). Doc bumps this to -12 in main.
float hardScan = -12.0;
// Hardness of pixels in scanline (-2 soft .. -4 hard).
float hardPix = -3.0;
// Display warp (0 none .. 1/8 extreme).
vec2 warp = vec2(1.0/64.0, 1.0/48.0);
// Shadow mask strength.
float maskDark = 0.5;
float maskLight = 1.5;

float ToLinear1(float c){ return (c <= 0.04045) ? c/12.92 : pow((c+0.055)/1.055, 2.4); }
vec3  ToLinear(vec3 c){ return vec3(ToLinear1(c.r), ToLinear1(c.g), ToLinear1(c.b)); }
float ToSrgb1(float c){ return (c < 0.0031308) ? c*12.92 : 1.055*pow(c, 0.41666) - 0.055; }
vec3  ToSrgb(vec3 c){ return vec3(ToSrgb1(c.r), ToSrgb1(c.g), ToSrgb1(c.b)); }

// Nearest emulated sample given floating point position and texel offset.
vec3 Fetch(vec2 pos, vec2 off){
    pos = (floor(pos*res + off) + vec2(0.5)) / res;
    return ToLinear(1.2 * Texel(source, pos.xy).rgb);
}

// Distance in emulated pixels to nearest texel.
vec2 Dist(vec2 pos){ pos = pos*res; return -((pos - floor(pos)) - vec2(0.5)); }

// 1D Gaussian.
float Gaus(float pos, float scale){ return exp2(scale*pos*pos); }

// 3-tap Gaussian filter along horizontal line.
vec3 Horz3(vec2 pos, float off){
    vec3 b = Fetch(pos, vec2(-1.0, off));
    vec3 c = Fetch(pos, vec2( 0.0, off));
    vec3 d = Fetch(pos, vec2( 1.0, off));
    float dst = Dist(pos).x;
    float scale = hardPix;
    float wb = Gaus(dst-1.0, scale);
    float wc = Gaus(dst+0.0, scale);
    float wd = Gaus(dst+1.0, scale);
    return (b*wb + c*wc + d*wd) / (wb+wc+wd);
}

// 5-tap Gaussian filter along horizontal line.
vec3 Horz5(vec2 pos, float off){
    vec3 a = Fetch(pos, vec2(-2.0, off));
    vec3 b = Fetch(pos, vec2(-1.0, off));
    vec3 c = Fetch(pos, vec2( 0.0, off));
    vec3 d = Fetch(pos, vec2( 1.0, off));
    vec3 e = Fetch(pos, vec2( 2.0, off));
    float dst = Dist(pos).x;
    float scale = hardPix;
    float wa = Gaus(dst-2.0, scale);
    float wb = Gaus(dst-1.0, scale);
    float wc = Gaus(dst+0.0, scale);
    float wd = Gaus(dst+1.0, scale);
    float we = Gaus(dst+2.0, scale);
    return (a*wa + b*wb + c*wc + d*wd + e*we) / (wa+wb+wc+wd+we);
}

// Scanline weight.
float Scan(vec2 pos, float off){
    float dst = Dist(pos).y;
    return Gaus(dst+off, hardScan);
}

// Allow nearest three lines to affect pixel.
vec3 Tri(vec2 pos){
    vec3 a = Horz3(pos, -1.0);
    vec3 b = Horz5(pos,  0.0);
    vec3 c = Horz3(pos,  1.0);
    float wa = Scan(pos, -1.0);
    float wb = Scan(pos,  0.0);
    float wc = Scan(pos,  1.0);
    return a*wa + b*wb + c*wc;
}

// Barrel distortion of scanlines.
vec2 Warp(vec2 pos){
    pos = pos*2.0 - 1.0;
    pos *= vec2(1.0 + (pos.y*pos.y)*warp.x, 1.0 + (pos.x*pos.x)*warp.y);
    return pos*0.5 + 0.5;
}

// RGB shadow mask.
vec3 Mask(vec2 pos){
    pos.x += pos.y*3.0;
    vec3 mask = vec3(maskDark);
    pos.x = fract(pos.x/6.0);
    if (pos.x < 0.333)      mask.r = maskLight;
    else if (pos.x < 0.666) mask.g = maskLight;
    else                    mask.b = maskLight;
    return mask;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords){
    // Position within the letterboxed target rect, 0..1.
    vec2 start = screen_coords - vec2(trg_x, trg_y);
    vec2 pos = Warp(start / vec2(trg_w, trg_h));
    vec3 col = Tri(pos) * Mask(screen_coords);
    return vec4(ToSrgb(col), 1.0);
}
]]
