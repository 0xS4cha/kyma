--- Ambient occlusion: a soft darkening of the floor at the foot of walls and
--- low cover, so the blocks look set on the ground instead of floating.
--- Walls and cover never move, so the occlusion of an arena is drawn once
--- into a quarter resolution canvas, blurred, and reused every frame. Doors
--- and glass change during a game and are left out.
local Occlusion = {}

local SCALE = 0.25

local BLUR = [[
extern vec2 direction;
extern vec2 size;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec2 step = direction / size;
    float sum = Texel(tex, uv).r * 0.2270270270;
    sum += Texel(tex, uv + step * 1.3846153846).r * 0.3162162162;
    sum += Texel(tex, uv - step * 1.3846153846).r * 0.3162162162;
    sum += Texel(tex, uv + step * 3.2307692308).r * 0.0702702703;
    sum += Texel(tex, uv - step * 3.2307692308).r * 0.0702702703;
    return vec4(sum, sum, sum, 1.0);
}
]]

local SHADE = [[
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    float o = Texel(tex, uv).r;
    return vec4(color.rgb, color.a * smoothstep(0.0, 0.85, o));
}
]]

local blurShader, shadeShader

local function shaders()
    if blurShader == nil then
        local ok, shader = pcall(love.graphics.newShader, BLUR)
        blurShader = ok and shader or false
        ok, shader = pcall(love.graphics.newShader, SHADE)
        shadeShader = ok and shader or false
    end
    return blurShader, shadeShader
end

--- @param arena table
--- @return love.Canvas?
local function build(arena)
    local blur = shaders()
    if not blur then return nil end
    local lg = love.graphics
    local w = math.max(1, math.ceil(arena.width * SCALE))
    local h = math.max(1, math.ceil(arena.height * SCALE))
    local a = lg.newCanvas(w, h)
    local b = lg.newCanvas(w, h)
    a:setFilter("linear", "linear")
    lg.push("all")
    lg.origin()
    lg.setShader()
    lg.setStencilTest()
    lg.setCanvas(a)
    lg.clear(0, 0, 0, 1)
    lg.scale(SCALE)
    lg.setColor(1, 1, 1, 1)
    for _, wall in ipairs(arena.walls or {}) do lg.rectangle("fill", wall.x, wall.y, wall.w, wall.h) end
    lg.setColor(0.6, 0.6, 0.6, 1)
    for _, block in ipairs(arena.cover or {}) do lg.rectangle("fill", block.x, block.y, block.w, block.h) end
    lg.origin()
    lg.setBlendMode("replace", "premultiplied")
    lg.setColor(1, 1, 1, 1)
    lg.setShader(blur)
    blur:send("size", { w, h })
    for _, radius in ipairs({ 2.4, 1.2 }) do
        lg.setCanvas(b)
        blur:send("direction", { radius, 0 })
        lg.draw(a)
        lg.setCanvas(a)
        blur:send("direction", { 0, radius })
        lg.draw(b)
    end
    lg.pop()
    b:release()
    return a
end

--- Darkens the floor around walls and cover. Drawn in world coordinates,
--- after the floor and before anything standing on it.
--- @param arena table
--- @param strength number
function Occlusion.draw(arena, strength)
    if arena.occlusion == nil then
        arena.occlusion = build(arena) or false
    end
    local canvas = arena.occlusion
    local _, shade = shaders()
    if not canvas or not shade then return end
    local lg = love.graphics
    lg.setShader(shade)
    lg.setColor(0, 0, 0, strength)
    lg.draw(canvas, 0, 0, 0, 1 / SCALE, 1 / SCALE)
    lg.setShader()
end

return Occlusion
