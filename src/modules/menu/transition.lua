--- The wipe between the menu and a game, drawn with a shader: the frame is
--- drawn into a canvas first, then the paper covers it behind a glowing red
--- edge that bends, smears and splits the colours of the picture it passes.
--- Falls back to the flat wipe when post effects are off or shaders fail.
local GM = require("src.core.index")
local Kit = require("src.ui.kit")

local Transition = {}

local SOURCE = [[
extern number top;
extern number bottom;
extern number side;
extern number band;
extern number time;
extern number motion;
extern vec2 size;
extern vec3 paper;
extern vec3 red;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec2 px = uv * size;
    float edge = mix(top, bottom, (px.y + 10.0) / (size.y + 20.0));
    vec2 line = vec2(bottom - top, size.y + 20.0);
    vec2 normal = normalize(vec2(line.y, -line.x)) * side;
    float d = (px.x - edge) * side * abs(normal.x);

    if (d < 0.0) {
        float shade = exp(d / 50.0) * 0.06;
        return vec4(paper * (1.0 - shade), 1.0);
    }
    if (d < band) {
        float x = d / band;
        float core = 1.0 - abs(x * 2.0 - 1.0);
        vec3 c = mix(red * 0.85, mix(red, vec3(1.0, 0.75, 0.7), 0.5), core);
        return vec4(c, 1.0);
    }

    float w = d - band;
    float pull = exp(-w / 90.0) * motion;
    float ripple = sin(px.y * 0.045 - time * 14.0) * exp(-w / 40.0) * motion;
    vec2 offset = normal * (pull * 26.0 + ripple * 4.0);
    vec2 split = normal * pull * 5.0;
    vec4 c = Texel(tex, (px - offset) / size);
    c.r = Texel(tex, (px - offset - split) / size).r;
    c.b = Texel(tex, (px - offset + split) / size).b;
    float glow = exp(-w / 14.0) * 0.55 + exp(-w / 60.0) * 0.12;
    c.rgb = mix(c.rgb, red, glow);
    c.rgb *= 1.0 - exp(-w / 26.0) * 0.12;
    return vec4(c.rgb, 1.0);
}
]]

local shader, canvas

--- @return love.Shader|false
local function getShader()
    if shader == nil then
        local ok, result = pcall(love.graphics.newShader, SOURCE)
        shader = ok and result or false
    end
    return shader
end

--- Draws the frame through the wipe shader while a wipe is running.
--- @param draw function draws the whole frame
--- @return boolean drawn false when the frame still has to be drawn normally
function Transition.draw(draw)
    local menu = GM.Menu
    if not menu or not menu.wipe then return false end
    if not require("src.modules.session.postfx").enabled() or not getShader() then return false end
    local lg = love.graphics
    local W, H = lg.getDimensions()
    if not canvas or canvas:getWidth() ~= W or canvas:getHeight() ~= H then
        canvas = lg.newCanvas(W, H)
    end
    local previous = lg.getCanvas()
    lg.setCanvas({ canvas, stencil = true })
    lg.clear(Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3], 1, true, 0)
    menu.shaderWipe = true
    local ok, err = pcall(draw)
    menu.shaderWipe = nil
    if previous then
        lg.setCanvas({ previous, stencil = true })
    else
        lg.setCanvas()
    end
    if not ok then error(err, 0) end

    local top, bottom, side, t = menu:wipeShape()
    local settings = menu.settings
    local motion = require("src.config.feel").strength[settings and settings.shake or 3] or 1
    lg.push("all")
    lg.origin()
    lg.setShader(shader)
    shader:send("top", top)
    shader:send("bottom", bottom)
    shader:send("side", side)
    shader:send("band", 14)
    shader:send("time", love.timer.getTime())
    shader:send("motion", math.min(1, motion) * (1 - t * 0.6))
    shader:send("size", { W, H })
    shader:send("paper", { Kit.PAPER[1], Kit.PAPER[2], Kit.PAPER[3] })
    shader:send("red", { Kit.RED[1], Kit.RED[2], Kit.RED[3] })
    lg.setBlendMode("replace", "premultiplied")
    lg.setColor(1, 1, 1, 1)
    lg.draw(canvas)
    lg.pop()
    menu:drawWipeLabel()
    return true
end

return Transition
