local Shaders = {}

local SOURCES = {}

SOURCES.post = [[
extern vec4 waves[8];
extern number aberration;
extern number hurt;
extern number low;
extern number desat;
extern number vignette;
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

SOURCES.glow = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    float d = length(uv * 2.0 - 1.0);
    float halo = exp(-d * d * 5.0) * (1.0 - smoothstep(0.85, 1.0, d));
    float core = 1.0 - smoothstep(0.0, 0.3, d);
    vec3 rgb = mix(color.rgb, vec3(1.0), core * 0.85);
    return vec4(rgb, color.a * clamp(halo + core * 0.6, 0.0, 1.0));
}
]]

SOURCES.light = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    float d = length(uv * 2.0 - 1.0);
    float fall = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
    float core = exp(-d * d * 40.0);
    vec3 rgb = mix(color.rgb, vec3(1.0), core * 0.7);
    return vec4(rgb, color.a * clamp(fall + core * 0.5, 0.0, 1.0));
}
]]

SOURCES.afterimage = [[
extern vec2 size;
extern number burn;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec2 drift = vec2(6.0, -4.0) / size * burn;
    vec3 a = Texel(tex, uv).rgb;
    vec3 b = Texel(tex, uv + drift).rgb;
    vec3 c = Texel(tex, uv - drift * 1.6).rgb;
    float grey = dot(a * 0.6 + b * 0.25 + c * 0.15, vec3(0.299, 0.587, 0.114));
    float bright = 1.0 - (1.0 - grey) * mix(0.35, 0.8, 1.0 - burn);
    vec3 rgb = vec3(bright) * mix(vec3(1.0, 0.97, 0.9), vec3(1.0), 1.0 - burn);
    vec2 center = uv - 0.5;
    float glare = exp(-dot(center, center) * 5.0) * 0.25 * burn;
    return vec4(min(rgb + glare, 1.0), color.a);
}
]]

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

SOURCES.footprint = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec2 p = uv * 2.0 - 1.0;
    float sole = length((p - vec2(0.28, 0.08)) / vec2(0.66, 0.86));
    float heel = length((p - vec2(-0.6, 0.0)) / vec2(0.34, 0.68));
    float shape = 1.0 - smoothstep(0.72, 1.0, min(sole, heel));
    float tread = 0.72 + 0.28 * smoothstep(0.35, 0.65, fract(p.x * 4.5 + abs(p.y) * 0.6));
    float rim = 0.85 + 0.15 * smoothstep(0.5, 0.95, min(sole, heel));
    return vec4(color.rgb, color.a * shape * tread * rim);
}
]]

SOURCES.shieldBreak = [[
extern number progress;
extern number spread;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hexDist(vec2 p) {
    p = abs(p);
    return max(dot(p, vec2(0.5, 0.8660254)), p.x);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec2 p = uv * 2.0 - 1.0;
    float r = length(p);
    float ang = abs(atan(p.y, p.x));
    float t = clamp(progress, 0.0, 1.0);
    float e = 1.0 - pow(1.0 - t, 3.0);

    vec2 q = p * 7.0;
    vec2 s = vec2(1.0, 1.7320508);
    vec2 a = mod(q, s) - s * 0.5;
    vec2 b = mod(q - s * 0.5, s) - s * 0.5;
    vec2 gv = dot(a, a) < dot(b, b) ? a : b;
    vec2 id = q - gv;
    float n = hash(id);
    float lines = smoothstep(0.38, 0.5, hexDist(gv));

    float radius = mix(0.4, 0.86, e) + (n - 0.5) * 0.14 * t;
    float width = mix(0.12, 0.3, t);
    float band = 1.0 - smoothstep(0.0, width, abs(r - radius));
    float arc = 1.0 - smoothstep(spread, spread + 0.2 + t * 0.6, ang);
    float alive = step(t * 1.05, n + 0.12);
    float shell = band * arc * alive * (0.6 + 0.4 * lines);

    float front = (1.0 - smoothstep(0.0, 0.035, abs(r - mix(0.42, 1.0, e)))) * arc;
    float bubble = (1.0 - smoothstep(0.0, 0.18, t)) * exp(-pow((r - 0.4) / 0.05, 2.0));

    float alpha = (shell * 1.3 + front * 0.9) * (1.0 - t * t) + bubble;
    vec3 rgb = mix(color.rgb, vec3(1.0), clamp(lines * 0.5 + bubble + (1.0 - t) * 0.25, 0.0, 1.0));
    return vec4(rgb, color.a * clamp(alpha, 0.0, 1.0));
}
]]

SOURCES.hitmark = [[
extern number progress;
extern number kill;
extern number whiten;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec2 p = uv * 2.0 - 1.0;
    float r = length(p);
    vec2 q = vec2(p.x + p.y, p.y - p.x) * 0.70710678;
    float d = min(abs(q.x), abs(q.y));
    float t = clamp(progress, 0.0, 1.0);
    float gap = mix(0.44, 0.54, t);
    float reach = mix(0.9, 0.96, t);
    float span = smoothstep(gap, gap + 0.05, r) * (1.0 - smoothstep(reach - 0.06, reach, r));
    float taper = mix(0.05, 0.022, smoothstep(gap, reach, r));
    float arms = (1.0 - smoothstep(taper * 0.6, taper, d)) * span;
    float halo = exp(-d * d * 220.0) * smoothstep(gap - 0.05, gap + 0.15, r) * (1.0 - smoothstep(reach - 0.1, reach + 0.25, r));
    float ringR = mix(0.45, 1.0, 1.0 - pow(1.0 - t, 2.0));
    float ring = kill * exp(-pow((r - ringR) / 0.025, 2.0)) * (1.0 - t);
    float fade = 1.0 - t * t;
    float alpha = clamp(arms + halo * 0.45 + ring * 0.9, 0.0, 1.0) * fade;
    vec3 rgb = mix(color.rgb, vec3(1.0), clamp(arms * whiten, 0.0, 1.0));
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

--- @return love.Image
function Shaders.pixel()
    if not pixel then
        local data = love.image.newImageData(1, 1)
        data:setPixel(0, 0, 1, 1, 1, 1)
        pixel = love.graphics.newImage(data)
    end
    return pixel
end

--- @return string
function Shaders.lightBlend()
    return require("src.ui.theme").dark() and "add" or "alpha"
end

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

--- @return boolean
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
