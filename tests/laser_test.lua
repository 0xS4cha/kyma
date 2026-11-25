local Renderer = require("src.modules.session.renderer")

return {
    {
        name = "you see your own laser with any gun",
        run = function()
            for _, kind in ipairs({ "pistol", "rifle", "shotgun", "sniper", "silencer", "lmg" }) do
                assert(Renderer.showsLaser({ weapon = kind }, true), kind)
            end
            assert(not Renderer.showsLaser({}, true), "no laser with fists")
        end
    },
    {
        name = "other players only show a laser with the sniper",
        run = function()
            assert(Renderer.showsLaser({ weapon = "sniper" }))
            for _, kind in ipairs({ "pistol", "rifle", "shotgun", "silencer", "lmg" }) do
                assert(not Renderer.showsLaser({ weapon = kind }), kind)
            end
        end
    }
}
