--- Soft shadows: the area a player sees is drawn into a half resolution mask,
--- blurred on the GPU, then used to lay the fog over the world. The edges of
--- the view cone and the shadows cast by walls fade out over a few pixels
--- instead of cutting hard, and they stay sharp close to the walls that cast
--- them (the blur grows with the distance from the viewer).
local Vision = require("src.game.vision")
local Config = require("src.config.game")

local Shadows = {}

local SCALE = 0.5
local cos, sin = math.cos, math.sin

local BLUR = [[
extern vec2 direction;
extern vec2 size;
extern vec2 origin;
extern number spread;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    float reach = clamp(length(screen - origin) / spread, 0.25, 1.0);
    vec2 step = direction / size * reach;
    float sum = Texel(tex, uv).r * 0.2270270270;
    sum += Texel(tex, uv + step * 1.3846153846).r * 0.3162162162;
    sum += Texel(tex, uv - step * 1.3846153846).r * 0.3162162162;
    sum += Texel(tex, uv + step * 3.2307692308).r * 0.0702702703;
    sum += Texel(tex, uv - step * 3.2307692308).r * 0.0702702703;
    return vec4(sum, sum, sum, 1.0);
}
]]

local FOG = [[
extern number deepen;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    float seen = Texel(tex, uv).r;
    float hidden = 1.0 - seen;
    float rim = seen * hidden * 4.0;
    return vec4(color.rgb, color.a * clamp(hidden + rim * deepen, 0.0, 1.0));
}
]]

local blurShader, fogShader
local maskA, maskB
local fadeMesh

local function shaders()
    if blurShader == nil then
        local ok, shader = pcall(love.graphics.newShader, BLUR)
        blurShader = ok and shader or false
        ok, shader = pcall(love.graphics.newShader, FOG)
        fogShader = ok and shader or false
    end
    return blurShader, fogShader
end

local function canvases()
    local W, H = love.graphics.getDimensions()
    local w, h = math.max(1, math.floor(W * SCALE)), math.max(1, math.floor(H * SCALE))
    if not maskA or maskA:getWidth() ~= w or maskA:getHeight() ~= h then
        maskA = love.graphics.newCanvas(w, h)
        maskB = love.graphics.newCanvas(w, h)
        maskA:setFilter("linear", "linear")
        maskB:setFilter("linear", "linear")
    end
    return maskA, maskB
end

--- The far end of the view range fades into the fog.
local function rangeMesh()
    if fadeMesh then return fadeMesh end
    local def = Config.vision
    local inner, outer = def.range * def.fade, def.range + 2
    local vertices = {}
    local steps = 96
    for k = 0, steps do
        local a = k / steps * 2 * math.pi
        local ca, sa = cos(a), sin(a)
        vertices[#vertices + 1] = { ca * inner, sa * inner, 0, 0, 1, 1, 1, 0 }
        vertices[#vertices + 1] = { ca * outer, sa * outer, 0, 0, 1, 1, 1, 1 }
    end
    fadeMesh = love.graphics.newMesh(vertices, "strip", "static")
    return fadeMesh
end

--- Whether soft shadows can be drawn: post effects on and shaders available.
--- @return boolean
function Shadows.available()
    local PostFX = require("src.modules.session.postfx")
    if not PostFX.enabled() then return false end
    local blur, fog = shaders()
    return blur ~= false and fog ~= false
end

--- Lays the fog over everything the viewer can't see. Called inside the
--- camera transform; it draws in screen space and leaves the transform as is.
--- @param arena table
--- @param viewer table { x, y, angle, dead }
--- @param camera table
--- @param fog table color
--- @return boolean drawn false when soft shadows are not available
function Shadows.draw(arena, viewer, camera, fog)
    if not Shadows.available() then return false end
    local blur, fogShader = shaders()
    local a, b = canvases()
    local lg = love.graphics
    local w, h = a:getWidth(), a:getHeight()
    local alive = (viewer.dead or 0) == 0

    lg.push("all")
    lg.setStencilTest()
    lg.setShader()
    lg.setBlendMode("alpha")
    lg.setCanvas(a)
    lg.clear(0, 0, 0, 1)
    if alive then
        lg.origin()
        lg.scale(SCALE)
        camera:apply()
        lg.setColor(1, 1, 1, 1)
        local cone, near = Vision.fans(arena, viewer.x, viewer.y, viewer.angle)
        for _, fan in ipairs({ cone, near }) do
            for k = 3, #fan - 3, 2 do
                lg.polygon("fill", fan[1], fan[2], fan[k], fan[k + 1], fan[k + 2], fan[k + 3])
            end
        end
        lg.setColor(0, 0, 0, 1)
        lg.draw(rangeMesh(), viewer.x, viewer.y)
        camera:clear()
    end

    local ox, oy = camera:toScreen(viewer.x, viewer.y)
    local spread = Config.vision.range * camera.scale * SCALE
    lg.origin()
    lg.setColor(1, 1, 1, 1)
    lg.setBlendMode("replace", "premultiplied")
    lg.setShader(blur)
    blur:send("size", { w, h })
    blur:send("origin", { ox * SCALE, oy * SCALE })
    blur:send("spread", spread)
    for _, radius in ipairs({ 2.2, 1.1 }) do
        lg.setCanvas(b)
        blur:send("direction", { radius, 0 })
        lg.draw(a)
        lg.setCanvas(a)
        blur:send("direction", { 0, radius })
        lg.draw(b)
    end
    lg.pop()

    lg.push("all")
    lg.origin()
    lg.setStencilTest()
    lg.setShader(fogShader)
    fogShader:send("deepen", require("src.ui.theme").dark() and 0.35 or 0.25)
    lg.setColor(fog)
    lg.draw(a, 0, 0, 0, 1 / SCALE, 1 / SCALE)
    lg.pop()
    return true
end

return Shadows
