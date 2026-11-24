local Theme = require("src.ui.theme")
local Kit = require("src.ui.kit")
local Settings = require("src.modules.menu.settings")

return {
    {
        name = "switching theme recolours the shared colours in place",
        run = function()
            local ink, paper = Kit.INK, Kit.PAPER
            Theme.apply("dark")
            assert(Kit.INK == ink and Kit.PAPER == paper, "same tables")
            assert(ink[1] > 0.5 and paper[1] < 0.2, "light ink on dark paper")
            Theme.apply("light")
            assert(ink[1] < 0.5 and paper[1] > 0.8, "dark ink on light paper")
        end
    },
    {
        name = "both palettes define the same colours",
        run = function()
            for key, value in pairs(Theme.palettes.light) do
                local other = Theme.palettes.dark[key]
                assert(other and #other == #value, key)
            end
            for key in pairs(Theme.palettes.dark) do assert(Theme.palettes.light[key], key) end
        end
    },
    {
        name = "your own body is lifted in the dark so it shows on the floor",
        run = function()
            local body = { 0.24, 0.25, 0.28 }
            Theme.apply("light")
            assert(Theme.lifted(body) == body)
            Theme.apply("dark")
            assert(Theme.lifted(body)[1] > 0.4)
            Theme.apply("light")
        end
    },
    {
        name = "the appearance setting defaults to light and is clamped",
        run = function()
            assert(Settings.parse(nil).theme == 1)
            assert(Settings.parse("theme=2\n").theme == 2)
            assert(Settings.parse("theme=7\n").theme == #Theme.order)
            assert(Settings.serialize(Settings.parse("theme=2\n")):find("theme=2", 1, true))
        end
    }
}
