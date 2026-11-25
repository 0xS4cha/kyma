--- GLSL shaders for in-game VFX, compiled lazily.
--- Every getter returns false when the GPU refuses a shader, so callers keep a plain fallback.
local Shaders = {}

local SOURCES = {}

-- Final composite of the world canvas: shockwave refraction, chromatic aberration,
-- vignette, damage and low-health edges, and desaturation.
SOURCES.post = [[
extern vec4 waves[8];   // screen x, screen y, radius (px), strength
extern number aberration; // px
extern number hurt;       // 0..1
extern number low;        // 0..1
extern number desat;      // 0..1
extern number vignette;   // 0..1
extern number time;
extern vec2 size;
extern vec3 tint;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec2 px = uv * size;
    vec2 offset = vec2(0.0);
    float glint = 0.0;
    for (int i = 0; i < 8; i++) {
        vec4 w = waves[i];
        if (w.w > 0.0) {
            vec2 d = px - w.xy;
            float dist = length(d);
            float band = 10.0 + w.z * 0.18;
            float x = (dist - w.z) / band;
            float ring = exp(-x * x) * x;
            vec2 dir = dist > 0.001 ? d / dist : vec2(0.0);
            offset -= dir * ring * w.w * 22.0;
            glint += exp(-x * x * 4.0) * w.w;
        }
    }
    vec2 suv = uv + offset / size;

    vec2 center = uv - 0.5;
    vec2 shift = center * (aberration + length(offset) * 0.35) / size.x * 2.0;
    vec4 c = Texel(tex, suv);
    c.r = Texel(tex, suv + shift).r;
    c.b = Texel(tex, suv - shift).b;
    c.rgb += vec3(glint * 0.08);

    float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    c.rgb = mix(c.rgb, vec3(grey) * vec3(0.92, 0.95, 1.04), clamp(desat, 0.0, 1.0));

    vec2 a = center * vec2(size.x / size.y, 1.0);
    float edge = smoothstep(0.35, 0.95, length(a));
    c.rgb *= 1.0 - edge * vignette;

    float pulse = 0.55 + 0.45 * sin(time * 5.5);
    float red = clamp(hurt * smoothstep(0.3, 1.0, length(a)) * 0.75
        + low * pulse * smoothstep(0.45, 1.05, length(a)) * 0.8, 0.0, 0.6);
    c.rgb = mix(c.rgb, tint, red);
    return c * color;
}
]]

-- Soft radial light: muzzle flashes, sparks, flashbangs. Drawn on a stretched 1x1 texture.
SOURCES.glow = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    float d = length(uv * 2.0 - 1.0);
    float halo = exp(-d * d * 5.0) * (1.0 - smoothstep(0.85, 1.0, d));
    float core = 1.0 - smoothstep(0.0, 0.3, d);
    vec3 rgb = mix(color.rgb, vec3(1.0), core * 0.85);
    return vec4(rgb, color.a * clamp(halo + core * 0.6, 0.0, 1.0));
}
]]

-- Soft beam along x with a hot core and a tapered tail: bullet tracers.
SOURCES.beam = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    float y = abs(uv.y * 2.0 - 1.0);
    float halo = exp(-y * y * 7.0);
    float core = 1.0 - smoothstep(0.0, 0.22, y);
    float taper = smoothstep(0.0, 0.25, uv.x) * (1.0 - smoothstep(0.92, 1.0, uv.x) * 0.6);
    vec3 rgb = mix(color.rgb, vec3(1.0), core * 0.6);
    return vec4(rgb, color.a * taper * clamp(halo * 0.55 + core, 0.0, 1.0));
}
]]

-- Billowing smoke grenade cloud: domain-warped fbm inside a ragged disc.
SOURCES.smoke = [[
extern number time;
extern number seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = p * 2.03 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec2 p = uv * 2.0 - 1.0;
    float d = length(p);
    vec2 q = p * 2.4 + vec2(seed, seed * 1.3);
    float warp = fbm(q * 1.6 - vec2(time * 0.07, time * 0.05));
    float n = fbm(q + vec2(time * 0.11, -time * 0.08) + warp * 1.4);
    float edge = 1.0 - smoothstep(0.5 + n * 0.3, 0.98, d);
    float alpha = clamp(edge * (0.88 + 0.3 * n), 0.0, 1.0);
    vec3 rgb = color.rgb * (0.86 + 0.28 * n);
    return vec4(rgb, color.a * alpha);
}
]]

local cache = {}
local pixel

--- @param name string
--- @return love.Shader|false
function Shaders.get(name)
    if cache[name] == nil then
        local ok, shader = pcall(love.graphics.newShader, SOURCES[name])
        cache[name] = ok and shader or false
    end
    return cache[name]
end

--- A 1x1 white texture whose stretched UVs drive the sprite shaders.
--- @return love.Image
function Shaders.pixel()
    if not pixel then
        local data = love.image.newImageData(1, 1)
        data:setPixel(0, 0, 1, 1, 1, 1)
        pixel = love.graphics.newImage(data)
    end
    return pixel
end

--- Blend mode for light sprites: additive glows only read on dark floors.
--- @return string
function Shaders.lightBlend()
    return require("src.ui.theme").dark() and "add" or "alpha"
end

--- Draw a soft radial glow, or a plain circle when shaders are unavailable.
--- @param x number
--- @param y number
--- @param radius number
--- @param r number
--- @param g number
--- @param b number
--- @param a number
function Shaders.glow(x, y, radius, r, g, b, a)
    local lg = love.graphics
    local shader = Shaders.get("glow")
    lg.setColor(r, g, b, a)
    if not shader then
        lg.circle("fill", x, y, radius * 0.4)
        return
    end
    lg.setShader(shader)
    lg.draw(Shaders.pixel(), x, y, 0, radius * 2, radius * 2, 0.5, 0.5)
    lg.setShader()
end

--- Draw a soft beam from (x1, y1) to (x2, y2).
--- @return boolean drawn false when shaders are unavailable
function Shaders.beam(x1, y1, x2, y2, width, r, g, b, a)
    local shader = Shaders.get("beam")
    if not shader then return false end
    local lg = love.graphics
    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    if length < 1 then return true end
    lg.setColor(r, g, b, a)
    lg.setShader(shader)
    lg.draw(Shaders.pixel(), x1, y1, math.atan2(dy, dx), length, width, 0, 0.5)
    lg.setShader()
    return true
end

return Shaders
